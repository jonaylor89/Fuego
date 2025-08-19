#!/bin/bash

# Fuego Setup Script
# Configures development environment and dependencies

set -e

echo "🔥 Setting up Fuego development environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check macOS version
check_macos_version() {
    echo "📱 Checking macOS version..."
    
    required_version="13.0"
    current_version=$(sw_vers -productVersion)
    
    if [[ $(echo "$current_version $required_version" | tr " " "\n" | sort -V | head -n1) != $required_version ]]; then
        echo -e "${RED}❌ macOS $required_version or later is required. Current version: $current_version${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ macOS version $current_version is compatible${NC}"
}

# Check Xcode installation
check_xcode() {
    echo "🛠️  Checking Xcode installation..."
    
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}❌ Xcode is not installed. Please install Xcode from the App Store.${NC}"
        exit 1
    fi
    
    xcode_version=$(xcodebuild -version | head -n1)
    echo -e "${GREEN}✅ Found $xcode_version${NC}"
    
    # Check if command line tools are installed
    if ! xcode-select -p &> /dev/null; then
        echo "📦 Installing Xcode command line tools..."
        xcode-select --install
        echo "Please complete the Xcode command line tools installation and run this script again."
        exit 1
    fi
}

# Check Swift version
check_swift() {
    echo "🏗️  Checking Swift version..."
    
    if ! command -v swift &> /dev/null; then
        echo -e "${RED}❌ Swift is not installed${NC}"
        exit 1
    fi
    
    swift_version=$(swift --version | head -n1)
    echo -e "${GREEN}✅ Found $swift_version${NC}"
}

# Create Xcode project if it doesn't exist
create_xcode_project() {
    if [ ! -f "Fuego.xcodeproj/project.pbxproj" ]; then
        echo "📱 Creating Xcode project..."
        
        # This would typically use a tool like xcodegen or swift package generate-xcodeproj
        # For now, we'll provide instructions
        echo -e "${YELLOW}⚠️  To create an Xcode project from the Swift Package:${NC}"
        echo "1. Open Xcode"
        echo "2. File > Open > Select the Fuego directory"
        echo "3. Xcode will automatically recognize the Package.swift file"
        echo ""
        echo "Alternatively, run:"
        echo "swift package generate-xcodeproj"
    else
        echo -e "${GREEN}✅ Xcode project exists${NC}"
    fi
}

# Setup build directory
setup_directories() {
    echo "📁 Setting up project directories..."
    
    mkdir -p .build
    mkdir -p DerivedData
    mkdir -p Archives
    
    echo -e "${GREEN}✅ Project directories created${NC}"
}

# Install development dependencies
install_dependencies() {
    echo "📦 Installing development dependencies..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}⚠️  Homebrew not found. Installing...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install useful development tools
    echo "Installing development tools..."
    brew install --quiet swiftlint || true
    brew install --quiet swiftformat || true
    brew install --quiet sourcery || true
    
    echo -e "${GREEN}✅ Development dependencies installed${NC}"
}

# Configure Git hooks
setup_git_hooks() {
    if [ -d ".git" ]; then
        echo "🔧 Setting up Git hooks..."
        
        # Pre-commit hook for SwiftLint
        cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook to run SwiftLint

if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
EOF
        
        chmod +x .git/hooks/pre-commit
        echo -e "${GREEN}✅ Git hooks configured${NC}"
    else
        echo -e "${YELLOW}⚠️  Not a Git repository, skipping Git hooks setup${NC}"
    fi
}

# Validate entitlements and Info.plist
validate_configuration() {
    echo "🔍 Validating project configuration..."
    
    if [ -f "Info.plist" ]; then
        echo "✅ Info.plist found"
        
        # Check for required keys
        if plutil -lint Info.plist > /dev/null 2>&1; then
            echo "✅ Info.plist is valid"
        else
            echo -e "${RED}❌ Info.plist has syntax errors${NC}"
            plutil -lint Info.plist
        fi
    else
        echo -e "${YELLOW}⚠️  Info.plist not found${NC}"
    fi
    
    if [ -f "Fuego.entitlements" ]; then
        echo "✅ Entitlements file found"
        
        # Check entitlements syntax
        if plutil -lint Fuego.entitlements > /dev/null 2>&1; then
            echo "✅ Entitlements file is valid"
        else
            echo -e "${RED}❌ Entitlements file has syntax errors${NC}"
            plutil -lint Fuego.entitlements
        fi
    else
        echo -e "${YELLOW}⚠️  Entitlements file not found${NC}"
    fi
}

# Test build
test_build() {
    echo "🏗️  Testing build..."
    
    if swift build > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Build successful${NC}"
    else
        echo -e "${RED}❌ Build failed. Run 'swift build' to see detailed errors.${NC}"
        exit 1
    fi
}

# Generate documentation
generate_docs() {
    echo "📚 Generating documentation..."
    
    if command -v sourcedocs &> /dev/null; then
        sourcedocs generate --spm-module Fuego --output-folder docs/
        echo -e "${GREEN}✅ Documentation generated in docs/${NC}"
    else
        echo -e "${YELLOW}⚠️  sourcedocs not available. Install with: brew install sourcedocs${NC}"
    fi
}

# Display next steps
show_next_steps() {
    echo ""
    echo "🎉 Fuego development environment setup complete!"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Update your Team ID in Fuego.entitlements"
    echo "2. Update bundle identifier in Info.plist to be unique"
    echo "3. Open Fuego.xcodeproj in Xcode (or use 'swift package generate-xcodeproj')"
    echo "4. Configure signing & capabilities in Xcode"
    echo "5. Build and run the project"
    echo ""
    echo -e "${GREEN}Useful commands:${NC}"
    echo "• swift build              - Build the project"
    echo "• swift test               - Run tests"
    echo "• swift run                - Run the application"
    echo "• swiftlint                - Lint the code"
    echo "• swiftformat .            - Format the code"
    echo ""
    echo -e "${GREEN}Required permissions for testing:${NC}"
    echo "• System Preferences > Security & Privacy > Privacy > Full Disk Access > Add Fuego"
    echo "• System Preferences > Security & Privacy > Privacy > Accessibility > Add Fuego"
    echo ""
    echo -e "${YELLOW}⚠️  Remember to handle entitlements and code signing for distribution!${NC}"
    echo ""
    echo "Happy coding! 🔥"
}

# Main execution
main() {
    echo "Starting Fuego setup process..."
    echo ""
    
    check_macos_version
    check_xcode
    check_swift
    setup_directories
    install_dependencies
    setup_git_hooks
    validate_configuration
    test_build
    generate_docs
    
    show_next_steps
}

# Run main function
main "$@"