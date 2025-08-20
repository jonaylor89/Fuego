#!/bin/bash
set -e

echo "🔧 Building Fuego for Developer ID distribution..."

# Clean previous builds
rm -rf build
mkdir -p build

# Build for release
swift build -c release

# Create app bundle structure
mkdir -p "build/Fuego.app/Contents/MacOS"
mkdir -p "build/Fuego.app/Contents/Resources"

# Copy executable
cp ".build/release/Fuego" "build/Fuego.app/Contents/MacOS/"

# Copy and process Info.plist
cp "Sources/Fuego/Info.plist" "build/Fuego.app/Contents/"
# Replace placeholder variables
sed -i '' 's/$(DEVELOPMENT_LANGUAGE)/en/g' "build/Fuego.app/Contents/Info.plist"
sed -i '' 's/$(EXECUTABLE_NAME)/Fuego/g' "build/Fuego.app/Contents/Info.plist"
sed -i '' 's/$(PRODUCT_NAME)/Fuego/g' "build/Fuego.app/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "build/Fuego.app/Contents/PkgInfo"

# Make executable
chmod +x "build/Fuego.app/Contents/MacOS/Fuego"

# Code sign for Developer ID (requires certificates)
if [[ -n "$DEVELOPER_ID_CERT" ]]; then
    echo "🔐 Code signing for Developer ID..."
    codesign --force --verify --verbose --sign "$DEVELOPER_ID_CERT" \
        --entitlements "Fuego-DeveloperID.entitlements" \
        --options runtime \
        "build/Fuego.app"
    
    echo "✅ Code signing complete"
    
    # Create ZIP for distribution
    cd build
    zip -r "Fuego.zip" "Fuego.app"
    cd ..
    
    # Notarize (requires Apple ID credentials)
    if [[ -n "$APPLE_ID" && -n "$APPLE_ID_PASSWORD" && -n "$TEAM_ID" ]]; then
        echo "📋 Submitting for notarization..."
        xcrun notarytool submit "build/Fuego.zip" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "$TEAM_ID" \
            --wait
        
        echo "🏷️ Stapling notarization..."
        xcrun stapler staple "build/Fuego.app"
        
        # Recreate ZIP with stapled app
        cd build
        rm "Fuego.zip"
        zip -r "Fuego.zip" "Fuego.app"
        cd ..
        
        echo "✅ Notarization complete"
    else
        echo "⚠️  Notarization credentials not found. App will not be notarized."
        echo "   Set APPLE_ID, APPLE_ID_PASSWORD, and TEAM_ID environment variables."
    fi
    
    # Create DMG
    if command -v create-dmg &> /dev/null; then
        echo "💿 Creating DMG..."
        create-dmg \
            --volname "Fuego" \
            --window-pos 200 120 \
            --window-size 800 400 \
            --icon-size 100 \
            --icon "Fuego.app" 200 190 \
            --hide-extension "Fuego.app" \
            --app-drop-link 600 185 \
            --format UDBZ \
            "build/Fuego.dmg" \
            "build/Fuego.app"
    else
        echo "📀 Creating simple DMG (install create-dmg for better DMG)..."
        hdiutil create -volname "Fuego" -srcfolder "build/Fuego.app" \
            -ov -format UDBZ "build/Fuego.dmg"
    fi
    
else
    echo "⚠️  No Developer ID certificate found. Skipping code signing."
    echo "   Set DEVELOPER_ID_CERT environment variable with your certificate name."
    
    # Create unsigned ZIP for development
    cd build
    zip -r "Fuego-unsigned.zip" "Fuego.app"
    cd ..
fi

echo "✅ Developer ID build complete!"
echo "   App bundle: build/Fuego.app"
if [[ -f "build/Fuego.zip" ]]; then
    echo "   ZIP: build/Fuego.zip"
fi
if [[ -f "build/Fuego.dmg" ]]; then
    echo "   DMG: build/Fuego.dmg"
fi