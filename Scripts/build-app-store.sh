#!/bin/bash
set -e

echo "🏪 Building Fuego for Mac App Store..."

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

# Code sign for Mac App Store (requires certificates)
if [[ -n "$MAC_APP_STORE_CERT" ]]; then
    echo "🔐 Code signing for Mac App Store..."
    codesign --force --verify --verbose --sign "$MAC_APP_STORE_CERT" \
        --entitlements "Fuego.entitlements" \
        "build/Fuego.app"
else
    echo "⚠️  No Mac App Store certificate found. Skipping code signing."
    echo "   Set MAC_APP_STORE_CERT environment variable with your certificate name."
fi

echo "✅ Mac App Store build complete: build/Fuego.app"

# Create .pkg for App Store submission
if [[ -n "$MAC_APP_STORE_INSTALLER_CERT" ]]; then
    echo "📦 Creating installer package..."
    productbuild --component "build/Fuego.app" /Applications \
        --sign "$MAC_APP_STORE_INSTALLER_CERT" \
        "build/Fuego-AppStore.pkg"
    echo "✅ App Store package created: build/Fuego-AppStore.pkg"
fi