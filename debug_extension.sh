#!/bin/bash

# Fuego Network Extension Debug Script
# Helps diagnose Network Extension installation and status

echo "🔥 Fuego Network Extension Debug Tool"
echo "===================================="
echo ""

# Check if running on macOS
if [[ $(uname) != "Darwin" ]]; then
    echo "❌ This script only works on macOS"
    exit 1
fi

# Get macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo "📋 System Info:"
echo "   macOS Version: $MACOS_VERSION"
echo "   Date: $(date)"
echo ""

# Check for Network Extensions
echo "🔍 Checking Network Extensions..."
echo ""

# Use systemextensionsctl to check system extensions
echo "📊 System Extensions Status:"
if command -v systemextensionsctl &> /dev/null; then
    systemextensionsctl list 2>/dev/null | grep -i fuego || echo "   No Fuego extensions found"
else
    echo "   systemextensionsctl not available"
fi
echo ""

# Check for Network Extension configurations
echo "📡 Network Extension Configurations:"
if [ -d "/Library/Preferences/SystemConfiguration/" ]; then
    ls -la /Library/Preferences/SystemConfiguration/ | grep -i network || echo "   No network configurations found"
else
    echo "   SystemConfiguration directory not found"
fi
echo ""

# Check App Groups for shared storage
echo "💾 App Groups Storage:"
CONTAINER_PATH="$HOME/Library/Group Containers/group.dev.getfuego.FuegoFocus"
if [ -d "$CONTAINER_PATH" ]; then
    echo "   ✅ App Group container exists: $CONTAINER_PATH"
    echo "   📁 Contents:"
    ls -la "$CONTAINER_PATH" 2>/dev/null || echo "      (empty or no permissions)"

    # Check for shared preferences
    PREFS_PATH="$CONTAINER_PATH/Library/Preferences/group.dev.getfuego.FuegoFocus.plist"
    if [ -f "$PREFS_PATH" ]; then
        echo "   ✅ Shared preferences found"
        echo "   📄 Blocked domains:"
        defaults read group.dev.getfuego.FuegoFocus blockedDomains 2>/dev/null || echo "      None configured"
        echo "   🔧 Filtering enabled:"
        defaults read group.dev.getfuego.FuegoFocus isFilteringEnabled 2>/dev/null || echo "      Not set"
    else
        echo "   ⚠️  No shared preferences found"
    fi
else
    echo "   ❌ App Group container not found"
    echo "   💡 This means the app hasn't run yet or App Groups aren't working"
fi
echo ""

# Check if Fuego app is running
echo "🏃 Process Status:"
if pgrep -f "Fuego" > /dev/null; then
    echo "   ✅ Fuego app is running"
    echo "   📊 Process info:"
    ps aux | grep -i fuego | grep -v grep | head -5
else
    echo "   ⚠️  Fuego app is not running"
fi
echo ""

# Check built app structure and extension embedding
echo "🔍 App Structure Check:"
APP_PATH="/Users/$(whoami)/Library/Developer/Xcode/DerivedData/Fuego-*/Build/Products/Debug/Fuego.app"
if ls $APP_PATH &>/dev/null; then
    ACTUAL_APP_PATH=$(ls -d $APP_PATH 2>/dev/null | head -1)
    echo "   ✅ Built app found: $ACTUAL_APP_PATH"

    # Check if extension is embedded
    EXTENSION_PATH="$ACTUAL_APP_PATH/Contents/PlugIns/FuegoContentFilter.appex"
    if [ -d "$EXTENSION_PATH" ]; then
        echo "   ✅ Extension embedded: FuegoContentFilter.appex"

        # Check extension Info.plist
        EXTENSION_INFO="$EXTENSION_PATH/Contents/Info.plist"
        if [ -f "$EXTENSION_INFO" ]; then
            echo "   📄 Extension Info.plist found"
            echo "   🔌 Extension Point: $(defaults read "$EXTENSION_INFO" NSExtension 2>/dev/null | grep NSExtensionPointIdentifier | cut -d'"' -f4)"
            echo "   🎯 Principal Class: $(defaults read "$EXTENSION_INFO" NSExtension 2>/dev/null | grep NSExtensionPrincipalClass | cut -d'"' -f4)"
        else
            echo "   ❌ Extension Info.plist missing"
        fi

        # Check extension entitlements
        echo "   🔐 Extension entitlements:"
        codesign -d --entitlements :- "$EXTENSION_PATH" 2>/dev/null | grep -A 10 "networkextension\|application-groups" || echo "      No relevant entitlements found"
    else
        echo "   ❌ Extension not embedded in app bundle"
    fi

    # Check main app entitlements
    echo "   🔐 Main app entitlements:"
    codesign -d --entitlements :- "$ACTUAL_APP_PATH" 2>/dev/null | grep -A 10 "networkextension\|application-groups" || echo "      No relevant entitlements found"
else
    echo "   ❌ Built app not found in DerivedData"
    echo "   💡 Try building the project first with Xcode"
fi
echo ""

# Check Console logs for recent Network Extension activity
echo "📝 Recent Network Extension Logs (last 5 minutes):"
log show --predicate 'subsystem == "dev.getfuego.FuegoFocus"' --info --last 5m 2>/dev/null | tail -10 || echo "   No recent logs found"
echo ""

# Network connectivity test
echo "🌐 Network Connectivity Test:"
if ping -c 1 example.com &> /dev/null; then
    echo "   ✅ Internet connectivity working"
else
    echo "   ❌ No internet connectivity (this might be due to blocking)"
fi
echo ""

# Provide troubleshooting steps
echo "🛠️  Troubleshooting Steps:"
echo ""
echo "1. 📱 Check System Settings:"
echo "   System Settings → General → Login Items & Extensions → Network Extensions"
echo "   Look for 'Fuego Content Filter' and ensure it's enabled"
echo ""
echo "2. 🔄 Reset Network Extension (if needed):"
echo "   sudo systemextensionsctl reset"
echo "   (This removes all system extensions - use with caution)"
echo ""
echo "3. 🔍 Monitor real-time logs:"
echo "   log stream --predicate 'subsystem == \"dev.getfuego.FuegoFocus\"'"
echo ""
echo "4. 🧪 Test with curl:"
echo "   curl -v http://example.com"
echo "   (Should show connection refused or redirect if blocking is working)"
echo ""
echo "5. 🚀 Open Network Extensions directly:"
echo "   open 'x-apple.systempreferences:com.apple.LoginItems-Settings.extension'"
echo ""
echo "6. 📋 Check entitlements manually:"
echo "   codesign -d --entitlements :- /path/to/Fuego.app"
echo "   codesign -d --entitlements :- /path/to/Fuego.app/Contents/PlugIns/FuegoContentFilter.appex"
echo ""
echo "7. 🔄 Force extension registration (if needed):"
echo "   sudo launchctl kickstart -kp system/com.apple.nesessionmanager"
echo ""
echo "8. 🧹 Clean build if issues persist:"
echo "   rm -rf ~/Library/Developer/Xcode/DerivedData/Fuego-*"
echo "   xcodebuild clean"
echo ""

echo "🔥 Debug complete! Check the output above for any issues."
echo ""
echo "💡 Common Issues:"
echo "• Extension not showing = entitlements mismatch or not embedded"
echo "• Extension disabled = user needs to enable in System Settings"
echo "• Blocking not working = shared storage or filtering logic issue"
