# 🔥 Fuego

A minimal macOS menu bar app that blocks distracting websites and apps while you focus.

- Blocks sites in every browser and app with a system-wide content filter, including subdomains
- Quits distracting apps, and keeps quitting them if they're reopened during a session
- Blocking ends on its own when the timer does
- Updates itself through [Sparkle](https://sparkle-project.org)

Requires macOS 15.5 or later.

## Install

[Download the latest release](https://github.com/jonaylor89/Fuego/releases/latest), or:

```bash
brew install --cask jonaylor89/tap/fuego
```

Move Fuego to Applications and open it from there. The first time you start a session with sites to block, macOS asks you to turn on Fuego's content filter in **System Settings → General → Login Items & Extensions → Network Extensions**, then to allow it to filter network content.

Blocked pages show the browser's connection error. Traffic through a VPN or proxy can get past the filter. Fuego never records or sends what you browse.

## Development

Open `Fuego.xcodeproj` in Xcode. Building needs an Apple Developer account with the Network Extension capability. macOS only activates the filter for apps in `/Applications`, so copy the build there to test website blocking. Check the filter with `systemextensionsctl list` and `log stream --info --predicate 'subsystem BEGINSWITH "dev.getfuego"'`.

Releases are built by the **Release** workflow (Actions → Release), which runs `scripts/release.sh` to sign, notarize, and publish the DMG and Sparkle appcast, then updates the [Homebrew tap](https://github.com/jonaylor89/homebrew-tap). The secrets it needs are listed in `.github/workflows/release.yml`.

## Website

The static site in `website/` is published at **https://getfuego.dev/**. Deploy that directory as the hosting root so `/robots.txt`, `/sitemap.xml`, and `/assets/` resolve correctly. Its metadata and sitemap use this canonical URL; update them together if the domain changes.

Run the offline SEO regression checks (also run in CI):

```bash
python3 scripts/test_website_seo.py
```

After deploying:

- Keep **Always Use HTTPS** enabled in Cloudflare (SSL/TLS → Edge Certificates). It is enabled for `getfuego.dev` and returns permanent `301` redirects to HTTPS while preserving paths and query strings. If a `www` hostname is added, permanently redirect it to the apex domain too.
- Confirm the homepage, `/robots.txt`, `/sitemap.xml`, and social preview image return `200` over HTTPS, with appropriate content types and no `X-Robots-Tag: noindex` header. Prefer a permanent redirect from `/index.html` to `/` (the current host uses `307`).
- Verify a domain property in Google Search Console using DNS, submit `https://getfuego.dev/sitemap.xml`, and inspect/request indexing for the homepage. Submit the same sitemap to Bing Webmaster Tools.
- Check the live URL in the Schema.org validator and Google Rich Results Test, and check its link preview in a social sharing debugger. The software schema describes the real, free app; it deliberately contains no invented ratings or reviews, so a Google software-app rich result is not guaranteed.

[Website](https://getfuego.dev) · [Issues](https://github.com/jonaylor89/Fuego/issues)
