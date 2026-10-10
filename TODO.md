# 🔥 Fuego Launch TODO

1.0.0 is out: https://github.com/jonaylor89/Fuego/releases/tag/v1.0.0

## ✅ Done

- [x] Content filter packaged as a system extension and activated with `OSSystemExtensionRequest`
- [x] Blocklist delivered to the filter through its configuration (the root-run filter can't read the app group)
- [x] Hostname detection for browsers that connect by IP (TLS SNI, HTTP `Host`, QUIC fallback)
- [x] Blocking ends when the timer does, and lapses on its own if the app dies
- [x] Code signing with a single team; app runs and blocks on a development-signed build
- [x] Unit tests for domain matching and hostname sniffing
- [x] App blocking (needed the main app out of the App Sandbox, which can't send the quit event; the filter is still sandboxed)

## 🔧 Release

- [x] Developer ID signing, with the content filter entitlement converted automatically
- [x] Notarization, stapling, and DMG (`scripts/release.sh`)
- [x] Sparkle auto-updates; tested 1.0.1 → 1.0.2 end to end, including the content filter swap
- [x] CI (build and test on every PR) and a Release workflow that publishes to GitHub Releases
- [x] Homebrew cask (`Casks/fuego.rb`); the Release workflow updates the tap
- [x] Add the repository secrets listed in CONTRIBUTING.md → Releasing
- [x] Run the Release workflow for 1.0.0 (notarized, appcast live, cask in the tap)
- [ ] Install 1.0.0 from the release and confirm it updates to the next release through Sparkle
- [x] README: download link and `brew install --cask jonaylor89/tap/fuego`
- [ ] Later: submit to the main homebrew-cask repository once Fuego meets its notability requirements
- [ ] Before 1 Feb 2027: the Developer ID certificate in `APPLE_CERTIFICATE_BASE64` (serial 70EC6B1EA0A0BC1A) expires. Export a newer one (the G2 certificates expire in 2030 and 2031) and update the two certificate secrets.

## 🧪 Testing Before Launch

- [ ] First-run approval flow from the notarized DMG on a Mac that has never had Fuego (this machine had development builds installed)
- [x] Chrome (incl. forced HTTP/3), Brave, Firefox (incl. DNS over HTTPS + ECH), and Safari block listed sites and load others
- [ ] Restart mid-session: blocking lifts by the session's end time, or as soon as Fuego relaunches (sessions aren't saved yet)
- [ ] App blocking quits apps from the notarized release build (check for an Automation prompt)
- [ ] Apple Silicon and Intel

## 🎬 Website & Media

- [ ] **Menu bar demo GIF** (`website/fuego-menubar-demo.gif`): click the menu bar icon, open the popover, start a session. 320px wide, under 1MB.
- [x] Point the download link at the latest release

## 💡 After Launch

- [ ] Session history (sessions are only kept in memory today)
- [ ] Pick apps to block from a list instead of typing names
- [ ] Notification when a session ends
