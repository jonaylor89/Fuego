# Fuego

A minimal focus app for macOS. Fuego lives in the menu bar, runs a focus timer, and while a session is running it blocks the websites and apps you've chosen.

## Features

- **Website blocking** — a Network Extension content filter (installed as a system extension) drops connections to blocked domains and their subdomains, in every browser and app.
- **App blocking** — blocked apps are quit when a session starts and whenever you try to open them during the session.
- **Focus timer** — set the length (default 25 minutes). When it reaches zero the session ends and everything is unblocked. Pausing a session also lifts blocking until you resume.
- **Menu bar only** — no Dock icon; click the flame to open Fuego.
- **Launch at login** — optional, off by default.

## Requirements

- macOS 15.5 or later (Apple Silicon or Intel)
- One-time approval of the Fuego system extension and its content filter

## Installation

Download the latest build from [GitHub Releases](https://github.com/jonaylor89/Fuego/releases/latest), move **Fuego.app** to **/Applications**, and open it.

> System extensions only activate when the app is run from `/Applications`.

The first time you start a session with websites on the blocklist (or press **set up** in settings), macOS asks you to approve Fuego:

1. Click **Open System Settings** in the "System Extension Blocked" prompt (or go to **System Settings → General → Login Items & Extensions → Network Extensions**) and enable **Fuego**.
2. Allow Fuego to **filter network content** when prompted.

See [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md) for details and troubleshooting.

## Usage

1. Click the flame in the menu bar.
2. Open settings (gear) and add websites (e.g. `reddit.com` — subdomains are blocked too) and apps (by name, e.g. `Slack`, or bundle ID, e.g. `com.tinyspeck.slackmacgap`).
3. Click **begin**. Use **pause** / **resume** / **end** as needed.

## Building

Open `Fuego.xcodeproj` in Xcode 26 or later. The `Fuego` scheme builds the app and embeds the `FuegoContentFilter` system extension in `Contents/Library/SystemExtensions`.

Website blocking only works in a build signed with a team that has the Network Extension and System Extension capabilities. See [CONTRIBUTING.md](CONTRIBUTING.md) for signing, testing, and release steps.

## Privacy

Everything stays on your Mac. The content filter only looks at the hostname of each connection to decide whether to block it; nothing is sent anywhere.
