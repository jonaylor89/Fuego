#!/bin/bash
set -e

echo "🏠 Building Fuego for local development..."

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

# Ad-hoc code signing (no certificate required)
echo "🔐 Ad-hoc code signing..."
codesign --force --deep --sign - "build/Fuego.app"

echo "✅ Local build complete: build/Fuego.app"
echo ""
echo "To install locally:"
echo "  cp -r build/Fuego.app /Applications/"
echo ""
echo "To run from build directory:"
echo "  open build/Fuego.app"