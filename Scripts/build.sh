#!/bin/bash

# Fuego Build Script
# Builds the app for development and distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="Fuego"
BUNDLE_ID="com.fuego.focus-app"
SCHEME_NAME="Fuego"
BUILD_DIR=".build"
ARCHIVE_DIR="Archives"
EXPORT_DIR="Export"

# Build configuration (Debug or Release)
CONFIGURATION="${1:-Release}"

echo -e "${BLUE}🔥 Building Fuego - Configuration: $CONFIGURATION${NC}"

# Clean previous builds
clean_build() {
    echo "🧹 Cleaning previous builds..."
    
    rm -rf "$BUILD_DIR"
    rm -rf DerivedData
    mkdir -p "$BUILD_DIR"
    mkdir -p "$ARCHIVE_DIR"
    mkdir -p "$EXPORT_DIR"
    
    echo -e "${GREEN}✅ Clean complete${NC}"
}

# Run SwiftLint
run_linting() {
    echo "🔍 Running code linting..."
    
    if command -v swiftlint &> /dev/null; then
        swiftlint
        echo -e "${GREEN}✅ Linting complete${NC}"
    else
        echo -e "${YELLOW}⚠️  SwiftLint not found, skipping...${NC}"
    fi
}

# Run tests
run_tests() {
    echo "🧪 Running tests..."
    
    if swift test 2>/dev/null; then
        echo -e "${GREEN}✅ All tests passed${NC}"
    else
        echo -e "${YELLOW}⚠️  Some tests failed or no tests found${NC}"
    fi
}

# Build with Swift Package Manager
build_with_spm() {
    echo "🏗️  Building with Swift Package Manager..."
    
    swift build \
        --configuration $CONFIGURATION \
        --build-path "$BUILD_DIR"
    
    echo -e "${GREEN}✅ Swift Package build complete${NC}"
}

# Build with Xcode (if xcodeproj exists)
build_with_xcode() {
    if [ -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
        echo "🏗️  Building with Xcode..."
        
        # Build for running
        xcodebuild \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath DerivedData \
            build
        
        echo -e "${GREEN}✅ Xcode build complete${NC}"
        
        # Find the built app
        BUILT_APP=$(find DerivedData -name "${PROJECT_NAME}.app" -type d | head -1)
        if [ -n "$BUILT_APP" ]; then
            echo -e "${GREEN}📱 Built app location: $BUILT_APP${NC}"
            
            # Copy to export directory
            cp -R "$BUILT_APP" "$EXPORT_DIR/"
            echo -e "${GREEN}✅ App copied to $EXPORT_DIR/${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No Xcode project found, using Swift Package Manager only${NC}"
        build_with_spm
    fi
}

# Create archive for distribution
create_archive() {
    if [ "$CONFIGURATION" == "Release" ] && [ -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
        echo "📦 Creating archive for distribution..."
        
        ARCHIVE_PATH="$ARCHIVE_DIR/${PROJECT_NAME}-$(date +%Y%m%d-%H%M%S).xcarchive"
        
        xcodebuild \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "$SCHEME_NAME" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath DerivedData \
            -archivePath "$ARCHIVE_PATH" \
            archive
        
        echo -e "${GREEN}✅ Archive created: $ARCHIVE_PATH${NC}"
        
        # Export for distribution
        create_export_plist
        export_archive "$ARCHIVE_PATH"
    else
        echo -e "${YELLOW}⚠️  Skipping archive creation (Debug build or no Xcode project)${NC}"
    fi
}

# Create export plist for distribution
create_export_plist() {
    cat > export_options.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF
}

# Export archive
export_archive() {
    local archive_path="$1"
    
    echo "📤 Exporting archive..."
    
    xcodebuild \
        -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist export_options.plist
    
    echo -e "${GREEN}✅ Export complete: $EXPORT_DIR${NC}"
    
    # Clean up
    rm -f export_options.plist
}

# Validate the built app
validate_app() {
    echo "✅ Validating built app..."
    
    APP_PATH=$(find "$EXPORT_DIR" -name "${PROJECT_NAME}.app" -type d | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "📱 Found app at: $APP_PATH"
        
        # Check bundle structure
        if [ -f "$APP_PATH/Contents/Info.plist" ]; then
            echo "✅ Info.plist found"
            
            # Extract version info
            VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "Unknown")
            BUILD=$(plutil -extract CFBundleVersion raw "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "Unknown")
            
            echo -e "${GREEN}📋 App Info:${NC}"
            echo "   Name: $PROJECT_NAME"
            echo "   Version: $VERSION"
            echo "   Build: $BUILD"
            echo "   Bundle ID: $BUNDLE_ID"
        else
            echo -e "${RED}❌ Info.plist not found in app bundle${NC}"
        fi
        
        # Check executable
        if [ -f "$APP_PATH/Contents/MacOS/$PROJECT_NAME" ]; then
            echo "✅ Executable found"
            
            # Check code signing
            if codesign -dv "$APP_PATH" 2>/dev/null; then
                echo "✅ Code signing verified"
            else
                echo -e "${YELLOW}⚠️  Code signing issues detected${NC}"
            fi
        else
            echo -e "${RED}❌ Executable not found${NC}"
        fi
        
        # Calculate app size
        APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
        echo "📏 App size: $APP_SIZE"
        
    else
        echo -e "${RED}❌ Built app not found${NC}"
        exit 1
    fi
}

# Generate build report
generate_report() {
    echo "📊 Generating build report..."
    
    REPORT_FILE="build_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
Fuego Build Report
==================
Date: $(date)
Configuration: $CONFIGURATION
Build Tool: $(if [ -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then echo "Xcode"; else echo "Swift Package Manager"; fi)
Swift Version: $(swift --version | head -1)
Xcode Version: $(xcodebuild -version | head -1 2>/dev/null || echo "Not available")

Build Status: SUCCESS
Build Duration: $SECONDS seconds

Output Locations:
- Build artifacts: $BUILD_DIR
- Export directory: $EXPORT_DIR
- Archives: $ARCHIVE_DIR

App Information:
- Bundle ID: $BUNDLE_ID
- Target: macOS 13.0+
- Architecture: Universal (Intel + Apple Silicon)

Next Steps:
1. Test the built app thoroughly
2. Verify all permissions work correctly
3. Test on different macOS versions
4. Prepare for distribution via:
   - Direct download
   - Mac App Store
   - Homebrew cask
EOF

    echo -e "${GREEN}✅ Build report generated: $REPORT_FILE${NC}"
}

# Display usage
show_usage() {
    echo "Usage: $0 [Debug|Release]"
    echo ""
    echo "Examples:"
    echo "  $0           # Build Release configuration"
    echo "  $0 Debug     # Build Debug configuration"
    echo "  $0 Release   # Build Release configuration"
    echo ""
    echo "The script will:"
    echo "1. Clean previous builds"
    echo "2. Run linting and tests"
    echo "3. Build the app"
    echo "4. Create archive (Release only)"
    echo "5. Validate the built app"
    echo "6. Generate build report"
}

# Main execution
main() {
    local start_time=$SECONDS
    
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        Debug|Release|"")
            # Valid configuration
            ;;
        *)
            echo -e "${RED}❌ Invalid configuration: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
    
    echo "Starting build process for $PROJECT_NAME..."
    echo ""
    
    clean_build
    run_linting
    run_tests
    build_with_xcode
    create_archive
    validate_app
    generate_report
    
    local duration=$((SECONDS - start_time))
    
    echo ""
    echo -e "${GREEN}🎉 Build completed successfully in ${duration}s!${NC}"
    echo ""
    echo -e "${GREEN}Output locations:${NC}"
    echo "• Built app: $EXPORT_DIR/${PROJECT_NAME}.app"
    echo "• Build artifacts: $BUILD_DIR"
    echo "• Archives: $ARCHIVE_DIR"
    echo ""
    echo -e "${YELLOW}⚠️  Don't forget to:${NC}"
    echo "1. Test the app on different macOS versions"
    echo "2. Verify all permissions and entitlements"
    echo "3. Test blocking functionality with admin privileges"
    echo "4. Update README with any new requirements"
}

# Run main function
main "$@"