#!/bin/bash
# Builds a notarized, stapled Fuego DMG plus a signed Sparkle appcast.
# The release workflow runs this in CI; it also runs as-is on a Mac.
#
#   scripts/release.sh
#
# Optional environment:
#   VERSION              Marketing version (default: MARKETING_VERSION from the project)
#   BUILD_NUMBER         Bundle version; must increase with every release (default: CURRENT_PROJECT_VERSION)
#   RELEASE_NOTES_FILE   Markdown shown in the Sparkle update dialog
#   ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID
#                        App Store Connect API key (Admin role) for signing and notarization.
#                        Without it, the account signed in to Xcode → Settings → Accounts is used.
#   SPARKLE_KEY_FILE     Sparkle EdDSA private key file. Without it, the key stored in the
#                        login keychain under the "fuego" account is used.
#   SPARKLE_FEED_URL, DOWNLOAD_URL_PREFIX
#                        For testing updates against a local server only; releases use GitHub.
#
# Signing: with a "Developer ID Application" identity in the keychain (always the case in CI),
# the export signs with it and the Developer ID provisioning profiles in signing/. Otherwise it
# falls back to the team's cloud-managed certificate, which only works through an Apple ID
# signed in to Xcode (Admin or Account Holder), not an API key.
set -euo pipefail

cd "$(dirname "$0")/.."
TEAM_ID=9HNXYM86C6
REPO=jonaylor89/Fuego
OUT=build/release
ARCHIVE=$OUT/Fuego.xcarchive
EXTENSION_ID=dev.getfuego.FuegoFocus.FuegoContentFilter
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

step() { printf '\n==> %s\n' "$*"; }

AUTH=(-allowProvisioningUpdates)
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
    AUTH+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

VERSION_OVERRIDES=()
[[ -n "${VERSION:-}" ]] && VERSION_OVERRIDES+=("MARKETING_VERSION=$VERSION")
[[ -n "${BUILD_NUMBER:-}" ]] && VERSION_OVERRIDES+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
[[ -n "${SPARKLE_FEED_URL:-}" ]] && VERSION_OVERRIDES+=("SPARKLE_FEED_URL=$SPARKLE_FEED_URL")

rm -rf "$OUT"
mkdir -p "$OUT"

if security find-identity -v -p codesigning | grep -q "Developer ID Application: .*($TEAM_ID)"; then
    SIGNING=manual
    PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
    mkdir -p "$PROFILE_DIR"
    for profile in signing/*.provisionprofile; do
        uuid=$(security cms -D -i "$profile" | plutil -extract UUID raw -)
        cp "$profile" "$PROFILE_DIR/$uuid.provisionprofile"
    done
else
    SIGNING=cloud
fi

export_options() {  # $1 = export | upload
    cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>developer-id</string>
	<key>teamID</key><string>$TEAM_ID</string>
	<key>destination</key><string>$1</string>
EOF
    if [[ $SIGNING == manual ]]; then
        cat <<EOF
	<key>signingStyle</key><string>manual</string>
	<key>signingCertificate</key><string>Developer ID Application</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>dev.getfuego.FuegoFocus</key><string>Fuego Developer ID</string>
		<key>$EXTENSION_ID</key><string>Fuego Content Filter Developer ID</string>
	</dict>
EOF
    else
        echo "	<key>signingStyle</key><string>automatic</string>"
    fi
    echo "</dict>"
    echo "</plist>"
}

step "Archiving"
xcodebuild -project Fuego.xcodeproj -scheme Fuego -configuration Release \
    -archivePath "$ARCHIVE" -derivedDataPath "$OUT/DerivedData" "${AUTH[@]}" \
    ${VERSION_OVERRIDES[@]+"${VERSION_OVERRIDES[@]}"} archive -quiet

VERSION=$(/usr/libexec/PlistBuddy -c "Print ApplicationProperties:CFBundleShortVersionString" "$ARCHIVE/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print ApplicationProperties:CFBundleVersion" "$ARCHIVE/Info.plist")
echo "Fuego $VERSION ($BUILD), $SIGNING signing"

step "Submitting for notarization"
export_options upload > "$OUT/ExportOptions.plist"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/ExportOptions.plist" \
    -exportPath "$OUT/upload" "${AUTH[@]}" -quiet

step "Waiting for Apple (usually a few minutes)"
for _ in $(seq 1 60); do
    if xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$OUT/app" "${AUTH[@]}" >"$OUT/notarize.log" 2>&1; then
        break
    fi
    if grep -qi "invalid\|rejected" "$OUT/notarize.log"; then
        cat "$OUT/notarize.log"
        echo "Notarization failed. Run: xcrun notarytool log <submission id> with your credentials for details." >&2
        exit 1
    fi
    sleep 30
done
APP=$OUT/app/Fuego.app
[[ -d "$APP" ]] || { cat "$OUT/notarize.log"; echo "Timed out waiting for notarization" >&2; exit 1; }

step "Verifying"
SYSEXT="$APP/Contents/Library/SystemExtensions/$EXTENSION_ID.systemextension"
xcrun stapler validate "$APP"
spctl --assess --type exec "$APP"
codesign --verify --strict --deep "$APP"
for bundle in "$APP" "$SYSEXT"; do
    entitlements=$(codesign -d --entitlements - --xml "$bundle" 2>/dev/null)
    if ! grep -q "content-filter-provider-systemextension" <<<"$entitlements"; then
        echo "$bundle is missing the Developer ID content filter entitlement" >&2
        exit 1
    fi
done
for key in SUFeedURL SUPublicEDKey; do
    [[ -n "$(plutil -extract "$key" raw "$APP/Contents/Info.plist" 2>/dev/null)" ]] || {
        echo "Info.plist is missing $key; Sparkle updates would be disabled" >&2
        exit 1
    }
done
[[ "$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(plutil -extract CFBundleVersion raw "$SYSEXT/Contents/Info.plist")" == "$BUILD" ]]
echo "Notarized, stapled, signed with Developer ID content filter entitlements, Sparkle configured"

step "Building DMG"
DMG_NAME=Fuego-$VERSION.dmg
DMG=$OUT/$DMG_NAME
STAGING=$OUT/dmg
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Fuego.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Fuego" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" -quiet

step "Signing the Sparkle appcast"
GENERATE_APPCAST=$OUT/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast
APPCAST_DIR=$OUT/appcast
mkdir -p "$APPCAST_DIR"
cp "$DMG" "$APPCAST_DIR/"
if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
    cp "$RELEASE_NOTES_FILE" "$APPCAST_DIR/Fuego-$VERSION.md"
fi
KEY_ARGS=(--account fuego)
[[ -n "${SPARKLE_KEY_FILE:-}" ]] && KEY_ARGS=(--ed-key-file "$SPARKLE_KEY_FILE")
"$GENERATE_APPCAST" "${KEY_ARGS[@]}" \
    --download-url-prefix "${DOWNLOAD_URL_PREFIX:-https://github.com/$REPO/releases/download/v$VERSION/}" \
    --link "https://github.com/$REPO/releases/tag/v$VERSION" \
    --maximum-versions 1 \
    --embed-release-notes \
    -o "$OUT/appcast.xml" \
    "$APPCAST_DIR"
grep -qF "$DMG_NAME" "$OUT/appcast.xml"
grep -qF 'sparkle:edSignature=' "$OUT/appcast.xml"

step "Cleaning up"
# Leftover copies of the app get registered with Launch Services, and macOS may
# open one of them instead of the one in /Applications. Keep only what gets published.
ditto -c -k --keepParent "$ARCHIVE/dSYMs" "$OUT/Fuego-$VERSION-dSYMs.zip"
while IFS= read -r copy; do
    "$LSREGISTER" -u "$copy" 2>/dev/null || true
done < <(find "$OUT" -name "*.app" -type d -prune)
rm -rf "$STAGING" "$APPCAST_DIR" "$ARCHIVE" "$OUT/DerivedData" "$OUT/upload" "$OUT/app" \
    "$OUT/ExportOptions.plist" "$OUT/notarize.log"
(cd "$OUT" && shasum -a 256 "$DMG_NAME" > SHA256SUMS.txt)

SHA=$(cut -d' ' -f1 "$OUT/SHA256SUMS.txt")
step "Done"
echo "DMG:      $DMG"
echo "Appcast:  $OUT/appcast.xml"
echo "dSYMs:    $OUT/Fuego-$VERSION-dSYMs.zip"
echo "Version:  $VERSION ($BUILD)"
echo "SHA-256:  $SHA"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "version=$VERSION"
        echo "build=$BUILD"
        echo "dmg=$DMG"
        echo "sha256=$SHA"
    } >> "$GITHUB_OUTPUT"
fi
