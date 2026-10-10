# Contributing to Fuego

Thank you for your interest in contributing to Fuego! This document provides guidelines for contributing to the project.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/<your-username>/fuego.git
   cd fuego
   ```
3. **Open the project** in Xcode:
   ```bash
   open Fuego.xcodeproj
   ```

## Development Setup

### Requirements
- macOS 15.5 or later
- Xcode 16.4 or later
- A paid Apple Developer account with the Network Extension capability, and your Mac registered as a development device

### Building
1. Open `Fuego.xcodeproj` in Xcode
2. Select your development team for the **Fuego** and **FuegoContentFilter** targets (Signing & Capabilities)
3. Build (⌘B). Run the unit tests with ⌘U.

### Testing Website Blocking
macOS only activates system extensions for apps in `/Applications`, so running straight from Xcode won't get you a working filter. The loop is:

1. Bump the build number (`CURRENT_PROJECT_VERSION`) whenever you change the filter. macOS keeps running the installed extension until it sees a new version.
2. Build, then copy the app into place:
   ```bash
   ditto ~/Library/Developer/Xcode/DerivedData/Fuego-*/Build/Products/Debug/Fuego.app /Applications/Fuego.app
   open /Applications/Fuego.app
   ```
   At launch the app replaces an older installed extension without asking again.
3. Watch the logs:
   ```bash
   systemextensionsctl list
   log stream --info --predicate 'subsystem BEGINSWITH "dev.getfuego"'
   ```
4. Check a blocked domain from the terminal. `curl --resolve` connects straight to an IP the system hasn't looked up, which exercises the TLS hostname path that Chrome and Firefox use:
   ```bash
   curl -I https://www.reddit.com                                 # blocked at connect
   curl -Ik --resolve www.reddit.com:443:1.1.1.1 https://www.reddit.com   # blocked from the TLS hello
   ```

### How the Pieces Fit
- **The app** (`Fuego/`) installs the filter with `OSSystemExtensionRequest` and writes the blocklist into the filter's configuration (`NEFilterManager`), see `FilterController.swift`.
- **The filter** (`FuegoContentFilter/`) is a system extension. It runs as root, so it can't read the user's app group container; it reads the blocklist from `filterConfiguration.vendorConfiguration` instead.
- **The app is not sandboxed.** Quitting blocked apps uses `NSRunningApplication.terminate()`, which sends a quit Apple Event that the App Sandbox blocks. This rules out the Mac App Store; Fuego ships as a notarized Developer ID app.
- **`Shared/`** is compiled into both targets: `FilterPolicy` (the blocklist and its expiry) and `HostSniffer` (reads hostnames from TLS ClientHellos and HTTP requests). Both are covered by `FuegoTests`.

## Releasing

Releases are built by the **Release** workflow (Actions → Release → Run workflow). It picks the next version from the latest GitHub release (patch, minor, or major bump, or an exact version), runs the tests, then runs `scripts/release.sh`, which:

1. Archives and signs with the Developer ID certificate and the provisioning profiles in `signing/`, using the `*-DeveloperID.entitlements` files: Developer ID requires the `content-filter-provider-systemextension` entitlement value, while development builds use `content-filter-provider`. The script fails if either bundle ends up without it.
2. Notarizes and staples the app, and checks Gatekeeper, the entitlements, and the Sparkle keys.
3. Builds `Fuego-<version>.dmg` and a Sparkle `appcast.xml` signed with the EdDSA key.

The workflow then publishes the GitHub release (DMG, appcast, checksums, dSYMs) with generated notes, and updates `Casks/fuego.rb` in [homebrew-tap](https://github.com/jonaylor89/homebrew-tap).

Installed copies update themselves through Sparkle: the app reads `https://github.com/jonaylor89/Fuego/releases/latest/download/appcast.xml`. On the next launch, Fuego asks macOS to swap in the new content filter, which keeps the user's approval. Build numbers come from the workflow run, so always release through the workflow; a lower build number than the installed one won't update.

### Repository secrets

| Secret | What it is |
| --- | --- |
| `APPLE_CERTIFICATE_BASE64` | Developer ID Application certificate and private key (`.p12`, base64) |
| `APPLE_CERTIFICATE_PASSWORD` | The password the `.p12` was exported with |
| `APPLE_API_PRIVATE_KEY_BASE64` | App Store Connect API key (`.p8`, base64), **Admin** role, team `9HNXYM86C6` |
| `APPLE_API_KEY_ID` | That key's ID |
| `APPLE_API_ISSUER_ID` | The issuer ID shown above the keys list |
| `SPARKLE_PRIVATE_ED_KEY_BASE64` | Sparkle private key: `generate_keys --account fuego -x key.txt`, then `base64 -i key.txt` |
| `HOMEBREW_TAP_TOKEN` | Optional. Fine-grained token with contents write access to `jonaylor89/homebrew-tap` |

CI can't use the cloud-managed Developer ID certificate that Xcode uses on your Mac (Apple only allows that for signed-in people, not API keys), hence the exported certificate. It signs with the Developer ID provisioning profiles in `signing/` ("Fuego Developer ID" and "Fuego Content Filter Developer ID"), which include all of the team's Developer ID certificates. The API key handles notarization.

If you change the content filter's capabilities or create a new Developer ID certificate, regenerate both profiles in the developer portal (Profiles → Developer ID, with every Developer ID Application certificate selected) and replace the files in `signing/`.

The Sparkle public key is in the project's `SPARKLE_PUBLIC_ED_KEY` build setting. Don't lose the private key: installed copies only accept updates signed with it.

### Releasing from a Mac

`scripts/release.sh` also runs locally. With a Developer ID Application certificate in your keychain it signs the same way CI does; without one, it falls back to the team's cloud-managed certificate through the account in Xcode → Settings → Accounts. It signs the appcast with the Sparkle key in your login keychain. Upload the files in `build/release/` by hand. To try an update against a local server first, set `SPARKLE_FEED_URL` and `DOWNLOAD_URL_PREFIX` (see the script header).

Test a release as a user would: download the DMG, drag Fuego to Applications in Finder, and open it from there. Opening it straight from the disk image runs a temporary copy that can't install the filter, so release builds refuse to run outside `/Applications`.

## Code Style

### Swift
- Use modern Swift concurrency (`async`/`await`, `@MainActor`)
- Follow standard Swift naming conventions
- Use `// MARK: -` comments to organize code sections
- Keep functions focused and single-purpose

### Structure
- Keep UI components in `Fuego/UI/`
- Keep core logic in `Fuego/Core/`
- Keep content filter code in `FuegoContentFilter/`
- Keep code that both the app and the filter need in `Shared/`
- Use meaningful file and folder names

### Comments
- Write clear, concise comments for complex logic
- Document public APIs with Swift documentation comments
- Avoid obvious comments that just restate the code

## Pull Request Process

### Before Submitting
1. **Test your changes** thoroughly
2. **Run the app** and verify core functionality works
3. **Test Network Extension** setup and blocking
4. **Check for console errors** or warnings
5. **Update documentation** if needed

### Pull Request Guidelines
1. **Create a focused PR** - one feature or fix per PR
2. **Write a clear title** describing the change
3. **Describe the changes** in the PR description:
   - What does this change?
   - Why is it needed?
   - How to test it?
4. **Link related issues** using "Fixes #123" or "Addresses #123"

### PR Description Template
```markdown
## What Changed
Brief description of the changes made.

## Why
Explain the motivation for this change.

## How to Test
1. Step one
2. Step two
3. Expected result

## Screenshots/Videos
If applicable, add screenshots or videos demonstrating the change.

## Checklist
- [ ] Tested on macOS 15.5+
- [ ] No console errors/warnings
- [ ] Network Extension functionality works
- [ ] Documentation updated if needed
```

## Issue Reporting

### Bug Reports
Use the bug report template and include:
- macOS version
- Fuego version
- Steps to reproduce
- Expected vs actual behavior
- Console logs if relevant

### Feature Requests
Use the feature request template and include:
- Clear description of the feature
- Use case or motivation
- Possible implementation ideas

## Types of Contributions

### Welcome Contributions
- **Bug fixes** - Always appreciated!
- **UI/UX improvements** - Keep it minimal and focused
- **Performance optimizations** - Especially for Network Extension
- **Documentation improvements** - Help others understand the code
- **Test coverage** - Help ensure reliability

### Discuss First
- **Major new features** - Create an issue to discuss approach
- **Breaking changes** - Need community input
- **Architecture changes** - Should align with project goals

## Development Notes

### Content Filter Notes
- The filter is a sandboxed system extension running as root
- Use `os.Logger` with the `dev.getfuego.FuegoFocus.FuegoContentFilter` subsystem; view it in Console.app or with `log stream --info`
- A filter change only takes effect once macOS replaces the installed extension, which needs a new build number

### Testing
- Test on both Intel and Apple Silicon Macs if possible
- Test the first-run approval flow on a Mac that has never installed Fuego
- Verify blocking still works after a restart
- Test in Safari, Chrome, and Firefox

## Code of Conduct

- **Be respectful** and constructive in discussions
- **Help others** learn and contribute
- **Focus on the code**, not personal preferences
- **Keep discussions relevant** to the project

## Questions?

- **General questions**: Start a [Discussion](https://github.com/jonaylor89/fuego/discussions)
- **Bug reports**: Open an [Issue](https://github.com/jonaylor89/fuego/issues)
- **Feature requests**: Open an [Issue](https://github.com/jonaylor89/fuego/issues) with the feature template

## License

By contributing to Fuego, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to Fuego! 🔥
