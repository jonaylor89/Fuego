# 🔥 Fuego Setup Instructions

Complete setup guide for getting Fuego working on your Mac.

## System Requirements

- **macOS**: 12.0 (Monterey) or later
- **Hardware**: Intel Mac or Apple Silicon Mac
- **Disk Space**: ~10MB
- **Network**: Required for initial setup and Network Extension registration

## Installation

### Option 1: Download DMG (Recommended)
1. Download `Fuego.dmg` from the [latest release](https://github.com/jonaylor89/fuego/releases)
2. Open the DMG file
3. Drag Fuego.app to your Applications folder
4. Eject the DMG

### Option 2: Homebrew
```bash
brew install --cask fuego
```

### Option 3: Build from Source
```bash
git clone https://github.com/jonaylor89/fuego.git
cd fuego
open Fuego.xcodeproj
# Build and run in Xcode
```

## Initial Setup

### Step 1: Launch Fuego
1. Open Fuego from Applications or Spotlight
2. Look for the 🔥 icon in your menu bar (top-right corner)
3. Click the icon to open the widget

### Step 2: Enable Network Extension
This is the most important step for website blocking to work.

1. Click the 🔥 menu bar icon
2. Go to Settings
3. Click **"Setup Network Extension"** button
4. **A system dialog will appear** asking for permission
5. Click **"Allow"** when prompted

### Step 3: System Preferences Setup
After clicking "Allow", you need to manually enable the extension:

1. Open **System Preferences** (or System Settings on macOS 13+)
2. Go to **Privacy & Security**
3. Scroll down to **Login Items & Extensions**
4. Click on **Network Extensions**
5. **Enable "Fuego Content Filter"**

### Step 4: Verify Setup
1. Return to Fuego in the menu bar
2. The status should now show "Active" or "Ready"
3. If it shows "Not Configured", repeat steps 2-3

## Usage

### Adding Websites to Block
1. Click the 🔥 menu bar icon
2. Click **Settings**
3. In the "Blocked Sites" section:
   - Type a domain name (like `reddit.com`)
   - Press Enter or click "Add"
4. The site will be added to your blocklist

### Starting a Focus Session
1. Click the 🔥 menu bar icon
2. Set your timer duration (5-120 minutes)
3. Click **"Start Focus"**
4. The timer will begin and websites will be blocked

### Adding Apps to Block
1. Click the 🔥 menu bar icon
2. Click **Settings**
3. In the "Blocked Apps" section:
   - Type the app name (like `Discord`)
   - Press Enter or click "Add"
4. The app will be prevented from launching during focus sessions

## Troubleshooting

### "Network Extension Not Working"

**Problem**: Websites aren't being blocked despite setup.

**Solutions**:
1. **Check System Preferences**:
   - Privacy & Security → Login Items & Extensions → Network Extensions
   - Ensure "Fuego Content Filter" is enabled
   
2. **Restart Fuego**:
   - Quit Fuego completely (right-click menu bar icon → Quit)
   - Relaunch from Applications
   
3. **Reset Network Extension**:
   - System Preferences → Privacy & Security → Login Items & Extensions
   - Turn OFF "Fuego Content Filter"
   - Wait 10 seconds
   - Turn it back ON
   - Restart Fuego

### "Permission Denied" Errors

**Problem**: System won't allow Network Extension setup.

**Solutions**:
1. **Check macOS version**: Requires macOS 12.0+
2. **Try as admin user**: Network Extensions require admin privileges
3. **Check System Integrity Protection**: Must be enabled (default)

### Blocked Sites Still Loading

**Problem**: Websites load despite being on blocklist.

**Solutions**:
1. **Wait 30 seconds**: Network Extension changes take time to propagate
2. **Check domain format**: Use `reddit.com` not `https://www.reddit.com`
3. **Clear browser cache**: Old pages might be cached
4. **Try incognito/private browsing**: Tests without cache

### App Not Responding

**Problem**: Fuego menu bar widget won't open.

**Solutions**:
1. **Force quit and restart**:
   ```bash
   killall Fuego
   open /Applications/Fuego.app
   ```
2. **Check Activity Monitor**: Look for multiple Fuego processes
3. **Restart your Mac**: Last resort for system-level issues

### Timer Not Working

**Problem**: Focus sessions don't start or track properly.

**Solutions**:
1. **Check system notifications**: Ensure Fuego can send notifications
2. **System Preferences**: Privacy & Security → Notifications → Fuego → Allow
3. **Restart the session**: Stop and start again

## Advanced Configuration

### Custom App Group
If you're building from source, you may need to change the app group:

1. In Xcode, select the Fuego target
2. Go to Signing & Capabilities
3. Update the App Group to match your team ID
4. Do the same for FuegoContentFilter target
5. Update `SharedBlocklist.swift` to use your app group name

### Debug Logging
To see Network Extension logs:

1. Open **Console.app**
2. Search for "Fuego" or "FuegoContentFilter"
3. Look for error messages or debugging info

### Manual Network Extension Registration
If automatic registration fails:

1. Open Terminal
2. Run: `systemextensionsctl list`
3. Look for Fuego-related extensions
4. If needed, reset: `systemextensionsctl reset`

## Uninstalling

### Complete Removal
1. **Quit Fuego**: Right-click menu bar icon → Quit
2. **Remove app**: Drag Fuego.app to Trash
3. **Clean up preferences**:
   ```bash
   rm -rf ~/Library/Preferences/com.fuego.focus-app.plist
   rm -rf ~/Library/Application\ Support/Fuego
   ```
4. **Remove Network Extension**:
   - System Preferences → Privacy & Security → Login Items & Extensions
   - Turn OFF "Fuego Content Filter"

### Homebrew Removal
```bash
brew uninstall --cask fuego
```

## FAQ

**Q: Is Fuego safe to use?**
A: Yes. Fuego is open-source and uses Apple's official Network Extension APIs. It only blocks network requests, doesn't intercept or store your data.

**Q: Why does it need Network Extension permissions?**
A: System-level website blocking requires these permissions. This is the most reliable way to block websites across all browsers and apps.

**Q: Can I use Fuego with VPN?**
A: Yes, but test thoroughly. Some VPN configurations might interfere with Network Extensions.

**Q: Does Fuego work with all browsers?**
A: Yes. Network Extensions work at the system level, blocking domains regardless of which browser you use.

**Q: Can I export/import my blocklist?**
A: Currently no, but this feature is planned for a future update.

## Getting Help

- **Bug reports**: [GitHub Issues](https://github.com/jonaylor89/fuego/issues)
- **Questions**: [GitHub Discussions](https://github.com/jonaylor89/fuego/discussions)
- **Feature requests**: [GitHub Issues](https://github.com/jonaylor89/fuego/issues) with feature template

---

**Still having trouble?** Create an issue on GitHub with:
- Your macOS version
- Fuego version
- Detailed description of the problem
- Console logs if available
