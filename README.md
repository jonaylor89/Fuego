# 🔥 Fuego

A minimal focus app for macOS that blocks distracting websites and apps to help you concentrate on what matters.

## Features

- **Website Blocking**: A system-wide content filter (Apple's Network Extension framework) drops connections to blocked sites in every browser and app
- **App Blocking**: Quits distracting apps, and keeps quitting them if they're reopened during a focus session
- **Focus Timer**: Sessions from 5 to 120 minutes; blocking ends on its own when the timer does
- **Menu Bar App**: Clean, minimal interface that stays out of your way
- **Automatic Updates**: Signed updates through [Sparkle](https://sparkle-project.org)
- **Open Source**: Built with Swift, fully open source and free to use

Requires macOS 15.5 or later.

## Download

**[Download the latest release](https://github.com/jonaylor89/Fuego/releases/latest)** (a notarized DMG), or install with [Homebrew](https://brew.sh):

```bash
brew install --cask jonaylor89/tap/fuego
```

Drag Fuego into your Applications folder and open it from there; macOS only turns on its content filter for apps in Applications. Fuego updates itself after that. See [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) for the one-time approval and troubleshooting.

## How It Works

Fuego ships a content filter as a system extension. The first time you start a session with sites on your blocklist, macOS asks you to allow it. When a session starts, the app hands the blocklist and the session's end time to the filter, and the filter drops any connection to a blocked domain or its subdomains (blocking `reddit.com` also blocks `old.reddit.com`).

Browsers like Chrome and Firefox often connect by IP address, so the filter also reads the hostname from the start of each connection (the TLS server name, or the HTTP `Host` header). During a session, QUIC (HTTP/3) connections whose hostname the filter can't see are dropped too; browsers then fall back to regular HTTPS, which the filter can check.

Tested with Safari, Chrome, Brave, and Firefox, including Chrome over HTTP/3 and Firefox with DNS over HTTPS and Encrypted Client Hello (ECH).

**Known limits:** blocked pages show the browser's connection error rather than a custom page, since HTTPS traffic can't be redirected. Traffic tunneled through a VPN or proxy can get past the filter. A browser that hides both its DNS lookups and the TLS hostname (ECH) from macOS could in principle reach a blocked site served by Cloudflare; none of the tested browsers do.

## Development

### Building from Source

```bash
git clone https://github.com/jonaylor89/fuego.git
cd fuego
open Fuego.xcodeproj
```

You need an Apple Developer account with the Network Extension capability, and your Mac registered as a development device. macOS only activates system extensions for apps in `/Applications`, so copy the built app there before testing website blocking. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development loop.

### Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup
- Code style guidelines  
- Pull request process
- How to report bugs

**Made with 🔥 for focused productivity**

[Website](https://getfuego.dev) • [Issues](https://github.com/jonaylor89/fuego/issues) • [Discussions](https://github.com/jonaylor89/fuego/discussions)
