# Contributing to Fuego

## Requirements

- macOS 15.5 or later
- Xcode 26 or later
- For website blocking: an Apple Developer team with the **Network Extensions** (content filter) and **System Extension** capabilities

## Project layout

```
Fuego/                    Menu bar app
  FuegoApp.swift          App delegate, status item, popover
  Core/                   FuegoCore (coordinator), SessionManager, models, persistence
  BlockingEngine/         BlockingEngine + AppBlocker, ContentFilterController (system extension + NEFilterManager)
  Timer/                  TimerEngine
  Settings/               SettingsManager (UserDefaults, launch at login)
  UI/                     SwiftUI views
FuegoContentFilter/       Network Extension content filter, built as a system extension
  main.swift              NEProvider.startSystemExtensionMode()
  FilterProvider.swift    NEFilterDataProvider that drops blocked hosts
Shared/                   Code compiled into both targets (DomainMatcher, FilterVendorConfiguration)
FuegoTests/               Swift Testing integration tests
FuegoUITests/             UI launch tests
website/                  getfuego.dev
```

## How website blocking is wired

1. `ContentFilterController.install()` submits an `OSSystemExtensionRequest` for `dev.getfuego.FuegoFocus.FuegoContentFilter`, then saves an `NEFilterManager` configuration pointing at it (disabled).
2. When a session starts, `startFiltering(blockedDomains:)` writes the blocklist into `NEFilterProviderConfiguration.vendorConfiguration` and enables the filter. The extension runs as root, so it can't read the user's defaults — the provider configuration is how the blocklist reaches it.
3. `FilterProvider` reloads the blocklist whenever `filterConfiguration` changes and drops flows whose host matches `DomainMatcher.isBlocked`.
4. When the session pauses or ends (including the timer reaching zero), the filter is disabled.

The system extension's bundle name must equal its bundle ID, which is why the product is `dev.getfuego.FuegoFocus.FuegoContentFilter.systemextension`.

The app itself is **not** sandboxed: a sandboxed app can't quit other apps (`NSRunningApplication.terminate()` returns `false`), which breaks app blocking. The system extension is sandboxed.

## Building and running

```bash
xcodebuild -project Fuego.xcodeproj -scheme Fuego build CODE_SIGNING_ALLOWED=NO
```

An unsigned build is enough to work on the UI, the timer, and app blocking. To exercise website blocking:

1. Set your team in **Signing & Capabilities** for both the `Fuego` and `FuegoContentFilter` targets. Both need the Network Extensions (Content Filter) capability and the same App Group; `Fuego` also needs System Extension.
2. Build, copy `Fuego.app` to `/Applications`, and run it from there.
3. While developing you can skip notarization with `systemextensionsctl developer on` (requires SIP to be disabled). Use `systemextensionsctl list` to inspect installed extensions and `systemextensionsctl reset` to remove them.

## Tests

```bash
xcodebuild test -project Fuego.xcodeproj -scheme Fuego -only-testing:FuegoTests \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS=
```

The overrides ad-hoc sign the test host without restricted entitlements, so tests run without a developer team. They cover:

- domain normalization/matching and the vendor-configuration round trip used by the filter
- the session lifecycle (start, pause, resume, end, timer completion) against a fake content filter
- settings persistence
- app blocking against a real app (launches and quits TextEdit — don't have unsaved TextEdit documents open)

The real content filter can't be tested in CI; check it manually with a signed build (see the release checklist).

## Dependencies

Pin every dependency to an exact version (no ranges). The only package is `swift-log`, pinned in `Fuego.xcodeproj` and `Package.resolved`.

## Releasing

1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` for all targets.
2. Archive the `Fuego` scheme and export with **Developer ID**. Developer ID builds need the `-systemextension` variants of the Network Extension entitlement (`content-filter-provider-systemextension`); confirm with `codesign -d --entitlements - Fuego.app/Contents/Library/SystemExtensions/*.systemextension` after export.
3. Notarize and staple (`xcrun notarytool submit … --wait`, `xcrun stapler staple Fuego.app`).
4. On a clean Mac: install to `/Applications`, approve the extension and filter, start a session with a blocked site and app, confirm both are blocked, wait for the timer to finish, confirm both are unblocked.
5. Publish a GitHub release with the zipped or DMG'd app.

## Pull requests

- Keep changes focused and run the tests above.
- Update the docs (README, SETUP_INSTRUCTIONS) when behavior changes.
- Report bugs and ideas in [GitHub Issues](https://github.com/jonaylor89/Fuego/issues).
