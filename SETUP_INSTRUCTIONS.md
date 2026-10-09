# 🔥 Fuego Setup Instructions

How to install, set up, and use Fuego.

## System Requirements

- **macOS**: 15.5 or later
- **Hardware**: Apple Silicon or Intel Mac
- **Permissions**: an administrator must approve Fuego's content filter once

## Installation

Fuego hasn't had its first release yet; build it from source for now (see [CONTRIBUTING.md](CONTRIBUTING.md)).

Fuego must live in your **Applications** folder. macOS won't turn on its content filter from anywhere else.

## Getting Started

1. Open Fuego. A 🔥 appears in your menu bar (there's no Dock icon).
2. Click the 🔥, then **settings**.
3. Set the session **duration**, and add the sites and apps you want to block:
   - **Sites**: type a domain like `reddit.com` and press Return. Pasting a full URL works too. Blocking a domain also blocks its subdomains.
   - **Apps**: type the app's name as it appears in the menu bar (`Discord`) or its bundle identifier (`com.hnc.Discord`).
4. Click **save**.
5. Click **begin**.

### First Session: Allowing the Content Filter

The first time you start a session with sites on your blocklist, macOS asks for two approvals:

1. **"System Extension Blocked"**: Fuego opens System Settings for you. Under **General → Login Items & Extensions**, find **Network Extensions** and switch **Fuego** on, then enter your password.
2. **"Fuego would like to filter network content"**: click **Allow**.

Once both are approved, the session starts. You won't be asked again.

You can also run this setup ahead of time from **settings → site blocking → set up**.

## During a Session

- **pause** lifts all blocking until you **resume**.
- **end** stops the session and lifts blocking.
- When the timer runs out, the session ends and blocking lifts on its own.
- Quitting Fuego ends the session. Even if Fuego crashes, sites unblock when the timer would have ended.

To quit, right-click the 🔥 and choose **Quit Fuego**, or click **quit** in the popover.

## Troubleshooting

### "allow fuego in system settings to block sites"
macOS is still waiting for your approval. Click the message, or go to **System Settings → General → Login Items & Extensions → Network Extensions** and switch Fuego on.

### "site blocking is off in system settings"
The filter was switched off in System Settings. Click the message, or go to **System Settings → General → Login Items & Extensions → Network Extensions** and switch Fuego back on.

### "move Fuego to /Applications first"
macOS only activates system extensions for apps in the Applications folder. Move Fuego there and open it again.

### "Move Fuego to Applications"
Fuego was opened from the disk image or another folder. Drag it into Applications in Finder, then open it from there.

### A Blocked Site Still Loads
- Make sure the session is running, not paused.
- Pages already loaded stay on screen. Reload to see the block.
- A browser may reuse a connection it opened before the session started. Quit and reopen the browser.
- Some sites (like x.com) keep a copy of their page frame offline. It may still appear, but nothing new loads into it.
- Turn off any VPN or proxy extension; traffic tunneled through them can bypass the filter.

### Checking the Filter
```bash
systemextensionsctl list    # Fuego Content Filter should be [activated enabled]
log stream --info --predicate 'subsystem BEGINSWITH "dev.getfuego"'
```
The log shows a `Blocked <domain>` line for each blocked connection.

## Uninstalling

1. Quit Fuego.
2. Drag Fuego from Applications to the Trash. macOS asks for your password to remove the content filter along with the app.
3. Optionally remove its settings:
   ```bash
   defaults delete dev.getfuego.FuegoFocus
   ```

## FAQ

**Does Fuego see my browsing?**
The filter checks the hostname of each connection against your blocklist, and only while a session is running. It doesn't record, store, or send anything anywhere. It only reads the opening bytes of a connection when it has no other way to learn the hostname, and it never decrypts traffic.

**Does it work in every browser?**
Yes. Safari, Chrome, Firefox, Arc and other browsers are all filtered, because the filter works at the system level.

**Why can't I see a "focus" page when a site is blocked?**
HTTPS connections can't be redirected without breaking encryption, so Fuego drops them and the browser shows its own connection error.

## Getting Help

- **Bug reports**: [GitHub Issues](https://github.com/jonaylor89/fuego/issues). Include your macOS version and the output of the commands under "Checking the Filter".
- **Questions**: [GitHub Discussions](https://github.com/jonaylor89/fuego/discussions)
