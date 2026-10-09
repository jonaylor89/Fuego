# Fuego Setup

## Requirements

- macOS 15.5 or later
- Fuego.app in `/Applications` (macOS refuses to activate system extensions from anywhere else)

## First run

1. Open Fuego. A flame appears in the menu bar; there's no Dock icon.
2. Click the flame → gear → add websites and/or apps → back.
3. Click **begin**.

If you've added websites, Fuego installs its content filter the first time a session starts (you can also do this ahead of time with **set up** under *website blocking* in settings). macOS then asks for two approvals:

1. **System extension** — macOS shows "System Extension Blocked". Open **System Settings → General → Login Items & Extensions**, scroll to **Network Extensions**, and turn on **Fuego**.
2. **Content filter** — macOS asks whether Fuego may "filter network content". Click **Allow**.

Once approved, the settings screen shows website blocking as **ready** (between sessions) or **blocking** (during a session). You don't need to approve again unless you uninstall Fuego.

App blocking needs no approval.

## How blocking works

- **Websites**: while a session runs, Fuego enables its content filter with your blocklist. Any connection to a blocked domain or one of its subdomains is dropped (`reddit.com` also blocks `www.reddit.com` and `old.reddit.com`). When the session is paused, ended, or the timer reaches zero, the filter is turned off.
- **Apps**: when a session starts, running blocked apps are asked to quit, and any blocked app launched during the session is quit right away. Apps match by name (`Slack`) or bundle ID (`com.tinyspeck.slackmacgap`), case-insensitively.
- Editing the blocklist during a session takes effect immediately.

## Settings

| Setting | Description |
| --- | --- |
| duration | Length of a focus session in minutes |
| launch at login | Start Fuego when you log in (off by default) |
| websites | Domains to block. URLs are accepted and trimmed to the domain |
| apps | App names or bundle IDs to quit during a session |

## Troubleshooting

**Website blocking says "not set up" or "needs approval"**
Press **set up**, then approve Fuego in **System Settings → General → Login Items & Extensions → Network Extensions**. Make sure Fuego.app is in `/Applications`.

**Website blocking says "error"**
The message under the status explains why. Common causes:
- The app isn't in `/Applications`.
- The build isn't signed with a team that has the Network Extension capability (local unsigned builds can't load the filter).
- You declined the content-filter prompt. Remove Fuego under **System Settings → Network → Filters** and press **set up** again.

**A site still loads during a session**
- Check the status says **blocking**.
- Browsers can keep an existing connection open; reload or restart the browser.
- Check the exact domain in the address bar; add it if it's on a different domain (e.g. `youtu.be` as well as `youtube.com`).

**Remove Fuego completely**
Quit Fuego and drag it from `/Applications` to the Trash. macOS asks to remove the system extension. You can also remove the filter under **System Settings → Network → Filters**.

**Logs**
```bash
log stream --predicate 'subsystem == "dev.getfuego.FuegoFocus"'
```
