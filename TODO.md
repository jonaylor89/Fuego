# 🔥 Fuego Launch TODO

Pre-launch checklist for getting Fuego ready for public release.

## 🎬 Website & Media

### High Priority
- [ ] **Create menu bar demo GIF** (fuego-menubar-demo.gif)
  - Show: menu bar icon → click → widget opens → start session → close widget
  - Size: 320px wide, under 1MB, 3-4 seconds
  - Place in `/website/` folder

- [ ] **Add real download links**
  - Replace `href="#"` placeholders with actual download URLs
  - Set up GitHub releases page first
  - Test all download links work

## 🔧 Xcode & App Configuration

### High Priority
- [ ] **Fix Network Extension registration**
  - Update `FuegoContentFilter.entitlements` with proper team ID
  - Update `Fuego.entitlements` with proper team ID and app group
  - Ensure app group name matches across main app and extension
  - Test extension loads and registers properly

- [ ] **Code signing setup**
  - Configure proper provisioning profiles
  - Set up Developer ID certificates for distribution
  - Enable hardened runtime
  - Configure notarization settings

- [ ] **Build configuration**
  - Set proper bundle identifiers
  - Update version numbers (start with 1.0.0)
  - Configure release build settings
  - Test archive builds successfully

### Medium Priority
- [ ] **Info.plist updates**
  - Add proper app description and copyright
  - Set minimum macOS version to 12.0
  - Add usage descriptions if needed
  - Configure proper icon references

- [ ] **Test Network Extension flow**
  - Test initial setup and permissions request
  - Verify blocking works correctly
  - Test enabling/disabling extension
  - Check system preferences integration

## 📦 Distribution

### High Priority
- [ ] **Create GitHub release workflow**
  - Set up GitHub Actions for automated builds
  - Create release templates
  - Test release process end-to-end

- [ ] **Create DMG installer**
  - Design simple DMG with app and Applications folder
  - Test DMG installation process
  - Ensure proper permissions and signing

- [ ] **Notarization setup**
  - Configure Apple Developer account
  - Set up notarization in Xcode
  - Test full notarization workflow

### Medium Priority
- [ ] **Homebrew Cask**
  - Fork homebrew-cask repository
  - Create cask file for Fuego
  - Test installation via `brew install --cask fuego`
  - Submit PR to homebrew-cask

Example cask file:
```ruby
cask "fuego" do
  version "1.0.0"
  sha256 "your-sha256-here"

  url "https://github.com/yourusername/fuego/releases/download/v#{version}/Fuego-#{version}.dmg"
  name "Fuego"
  desc "Focus app that blocks distracting websites and apps"
  homepage "https://getfuego.dev"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Fuego.app"

  zap trash: [
    "~/Library/Preferences/com.fuego.focus-app.plist",
    "~/Library/Application Support/Fuego",
  ]
end
```

## 📝 Documentation

### High Priority
- [ ] **Update main README.md**
  - Add screenshots or GIF
  - Update build instructions
  - Add proper setup guide
  - Include troubleshooting section

- [ ] **Create SETUP_INSTRUCTIONS.md**
  - Detailed Network Extension setup
  - System requirements
  - Troubleshooting common issues
  - Permission explanations

### Medium Priority
- [ ] **Add contributing guidelines**
  - CONTRIBUTING.md file
  - Code style guidelines
  - Pull request template

## 🚀 Launch Preparation

### High Priority
- [ ] **Test full user journey**
  - Download → Install → Setup → Use → Uninstall
  - Test on fresh macOS installation
  - Verify all permissions work correctly

### Medium Priority
- [ ] **Launch assets**
  - Social media images (Twitter, etc.)
  - Product Hunt submission assets
  - Press kit with screenshots

- [ ] **Community setup**
  - GitHub issues templates

## 🔍 Final Testing

### Before Launch
- [ ] **Cross-platform testing**
  - Test on Intel and Apple Silicon Macs
  - Test on macOS 12, 13, 14+
  - Verify Network Extension works on all versions

- [ ] **Security review**
  - Code review for security issues
  - Ensure no secrets in code
  - Verify proper permission handling

- [ ] **Performance testing**
  - Test with large blocklists
  - Verify low memory usage
  - Check for memory leaks

## 📋 Launch Day

### Ready to Ship
- [ ] **Create first release**
  - Tag version 1.0.0
  - Upload DMG to GitHub releases
  - Update website download links

- [ ] **Submit to directories**
  - Submit Homebrew cask PR
  - Add to relevant software directories
  - Post on social media

---

## Notes

- **Priority**: Focus on High Priority items first
- **Testing**: Each item should be tested thoroughly
- **Documentation**: Keep user-facing docs simple and clear
- **Timeline**: Allow 1-2 weeks for high priority items

**Current Status**: 🟡 In Progress
