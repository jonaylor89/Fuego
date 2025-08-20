# Fuego Distribution Guide

This guide covers distributing Fuego through different channels: Mac App Store, GitHub Releases, and Homebrew.

## Quick Start

For local development and testing:
```bash
./scripts/build-local.sh
```

## Distribution Channels

### 1. Mac App Store 📱

**Requirements:**
- Apple Developer Program membership ($99/year)
- Mac App Store certificates
- App Store review approval

**Setup:**
1. Create app in App Store Connect
2. Get Mac App Store certificates from Apple Developer portal
3. Set environment variables:
   ```bash
   export MAC_APP_STORE_CERT="3rd Party Mac Developer Application: Your Name (TEAM123)"
   export MAC_APP_STORE_INSTALLER_CERT="3rd Party Mac Developer Installer: Your Name (TEAM123)"
   ```
4. Build and submit:
   ```bash
   ./scripts/build-app-store.sh
   xcrun altool --upload-app -f build/Fuego-AppStore.pkg -t macos -u your@apple.id
   ```

**Pros:**
- Built-in distribution and updates
- User trust and security
- No need for separate hosting

**Cons:**
- App Store review process (1-7 days)
- Apple's 30% revenue cut (if paid)
- Sandboxing restrictions

### 2. GitHub Releases (Recommended) 🚀

**Requirements:**
- Apple Developer account for code signing (optional but recommended)
- GitHub repository

**Setup:**
1. Get Developer ID certificates from Apple Developer portal
2. Set repository secrets in GitHub:
   ```
   DEVELOPER_ID_APPLICATION_CERT (base64 encoded certificate)
   DEVELOPER_ID_APPLICATION_KEY (base64 encoded private key)
   NOTARIZATION_USERNAME (your Apple ID)
   NOTARIZATION_PASSWORD (app-specific password)
   NOTARIZATION_TEAM_ID (your team ID)
   KEYCHAIN_PASSWORD (any secure password)
   ```
3. Create a release:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

The GitHub Action will automatically:
- Build the app
- Code sign and notarize
- Create DMG and ZIP files
- Upload to GitHub releases
- Update Homebrew cask formula

**Pros:**
- Full control over distribution
- Fast releases (no review process)
- Free hosting
- Automatic updates via GitHub API

**Cons:**
- Users need to trust your certificates
- Manual setup for code signing

### 3. Homebrew Cask 🍺

**Automatic (via GitHub Releases):**
The GitHub Action automatically generates a Homebrew cask formula when you create a release.

**Manual Setup:**
1. Fork [homebrew-cask](https://github.com/Homebrew/homebrew-cask)
2. Add the `fuego.rb` file to `Casks/` directory
3. Update the formula with correct URLs and checksums
4. Submit a pull request

Users can then install with:
```bash
brew install --cask fuego
```

**Pros:**
- Easy installation for developers
- Automatic dependency management
- Built-in update system

**Cons:**
- Requires community approval
- Package must follow Homebrew guidelines

## Code Signing & Notarization

### For Mac App Store:
- Uses Mac App Store certificates
- App Sandbox enabled
- Automatic notarization through App Store

### For Developer ID:
- Uses Developer ID certificates
- Hardened Runtime enabled
- Manual notarization required

### Getting Certificates:

1. **Join Apple Developer Program** ($99/year)
2. **Create Certificates** in Apple Developer portal:
   - Developer ID Application (for direct distribution)
   - Mac App Store certificates (for App Store)
3. **Download and install** certificates in Keychain Access
4. **Create app-specific password** for notarization in Apple ID settings

## Security Features

### Entitlements:
- **App Sandbox** (Mac App Store only)
- **Hardened Runtime** (required for notarization)
- **AppleScript automation** access
- **Network access** for blocking features

### Privacy:
- **System permissions** are requested at runtime
- **No analytics** or data collection
- **Local data storage** only

## Build Scripts

### `scripts/build-local.sh`
- Ad-hoc signed for local development
- No certificates required
- Quick testing and development

### `scripts/build-developer-id.sh`
- Full Developer ID signing and notarization
- Creates DMG and ZIP files
- Ready for direct distribution

### `scripts/build-app-store.sh`
- App Store signing and packaging
- Creates .pkg for App Store submission
- App Sandbox enabled

## Troubleshooting

### Common Issues:

**Code signing fails:**
- Check certificate names with `security find-identity -v -p codesigning`
- Ensure certificates are in login keychain
- Try `security unlock-keychain` if prompted for password

**Notarization fails:**
- Check Apple ID has 2FA enabled
- Use app-specific password, not Apple ID password
- Wait 1-2 minutes for notarization to process

**App won't run:**
- Check Gatekeeper: `spctl -a -t exec -vv path/to/Fuego.app`
- Try right-click → Open instead of double-click
- Check Console app for error messages

### Environment Variables:

For local builds:
```bash
# Developer ID Distribution
export DEVELOPER_ID_CERT="Developer ID Application: Your Name (TEAM123)"
export APPLE_ID="your@apple.id"
export APPLE_ID_PASSWORD="app-specific-password"
export TEAM_ID="TEAM123"

# Mac App Store
export MAC_APP_STORE_CERT="3rd Party Mac Developer Application: Your Name (TEAM123)"
export MAC_APP_STORE_INSTALLER_CERT="3rd Party Mac Developer Installer: Your Name (TEAM123)"
```

## Release Checklist

- [ ] Update version in `Info.plist`
- [ ] Test app functionality locally
- [ ] Update `CHANGELOG.md`
- [ ] Create Git tag (`git tag v1.0.0`)
- [ ] Push tag (`git push origin v1.0.0`)
- [ ] Monitor GitHub Action progress
- [ ] Test downloaded release
- [ ] Update Homebrew cask if needed
- [ ] Announce release

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Homebrew Cask Guidelines](https://docs.brew.sh/Cask-Cookbook)