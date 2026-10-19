# Catecho

A quiet morning briefing, shaped like a radio.

Catecho brings back the feeling of checking a newspaper or turning on a small radio: a finite edition, clear information, and time to get on with your day. It lives at the edge of your Mac's desktop as an antenna. Click or pull it up when you have a moment.

| Classic | Flat |
| --- | --- |
| ![Classic radio with an ivory case and sage e-paper display](docs/images/classic.png) | ![Flat appearance with the same reading layout](docs/images/flat.png) |

The screenshots show sample editions. The app fetches current information from the selected sources.

## What it does

- A draggable edge antenna, a floating radio window, and matching Classic and Flat appearances.
- A small, finite edition with source links, refresh status, and an offline cache.
- AI news, GitHub trends, research, games, NBA, education, psychology, philosophy, science, and technology stations.
- Multiple research topics at once, including AI and physics. GitHub shows recent star gains from Trending rather than lifetime-star rankings.
- Custom stations: paste website links to discover RSS/Atom feeds, with a public-webpage reader as a fallback.
- A back panel with physical-style controls, a mouse-driven flip, and a battery compartment that shows update activity.
- English, Simplified Chinese, and Traditional Chinese interfaces. On supported Macs, Apple's on-device Translation framework can translate article snippets while keeping an Original toggle.
- An optional Codex station for all local sessions: recorded tokens per second, minute, or hour, with an activity chart and numeric-only local cache.
- A first-launch tuning guide for topics, research subjects, language, and optional start at login, using the radio's own physical-style controls.

Built with SwiftUI and AppKit. No third-party package dependencies, app account, paid AI API, or cloud backend. Each Mac fetches its selected sources directly. Stories are publisher headlines and excerpts, not AI-written summaries.

## Try the beta

Download the app-only ZIP from [Releases](https://github.com/Real-Etix/Catecho/releases), extract it, and copy **Catecho.app** to **Applications**. On first launch, choose topics, language, and whether to start at login. Click **Start reading** to fetch your stations. Later launches begin with the small antenna at the screen edge. A radio symbol in the menu bar opens or quits it and offers **Set up your radio…** to revisit setup.

[Preview the first-launch setup](docs/images/setup-classic.png).

Current requirements:

- Apple Silicon Mac (M1 or newer).
- macOS 14 or later; on-device article translation requires macOS 15 or later and a supported language pair.
- Internet access to refresh sources; previously fetched editions remain readable offline.

This is an early prototype. The downloadable build is ad-hoc signed and **not Developer ID signed or Apple-notarized**. Gatekeeper may block it on another Mac. A locally compiled build is an alternative for technical testers; a notarized distribution is planned separately. Intel and Windows builds are not included.

Enable **Start at login** in setup or the radio's back settings after moving the app to Applications. Catecho reports macOS's actual status and links to Login Items if approval is needed. Updates run while the app is open and the Mac is awake. There is no automatic app updater yet; later builds are downloaded from Releases.

[Codex monitoring: enable it and understand the numbers](docs/CODEX-MONITOR.md).

[Read the user guide](docs/USER-GUIDE.md) for controls, sources, refresh behavior, translation, and custom stations.

## Build from source

Install Apple's Command Line Tools or Xcode, then run on an Apple Silicon Mac:

```sh
git clone https://github.com/Real-Etix/Catecho.git
cd Catecho
./build.sh
open dist/Catecho.app
```

The build script creates and ad-hoc signs `dist/Catecho.app`. An optional first argument changes the output directory. It does not install or replace an existing app in Applications. Close the installed copy before testing a different build: both use the same preferences and cache identity.

`Package.swift` can be opened in Xcode. Plain `swift build` produces the executable, while `build.sh` assembles the complete macOS app, metadata, and icon. The script includes a local workaround for duplicate SwiftBridging module maps in some Command Line Tools installations; it does not modify the system toolchain.

## Tests

```sh
./test.sh          # Deterministic parsing, model, UI logic, setup, and login adapter tests
./test.sh --live   # Also contacts the public providers
```

Native diagnostics are available after building:

```sh
dist/Catecho.app/Contents/MacOS/LittleRadio --geometry-test
dist/Catecho.app/Contents/MacOS/LittleRadio --smoke-test
dist/Catecho.app/Contents/MacOS/LittleRadio --setup-preview
dist/Catecho.app/Contents/MacOS/LittleRadio --codex-preview --show
```

The smoke test briefly creates a native radio panel. Setup preview uses a separate `Catecho.SetupPreview` preferences domain and temporary cache; it preserves its test choices across launches and disables login-item operations. Codex preview uses a separate `Catecho.CodexPreview` domain and sample activity; `--codex-live-preview --show` reads real local usage into a temporary numeric cache. Both disable login-item operations. Keep the installed copy closed when testing a second bundle with the same identifier. See [verification notes](docs/VERIFICATION.md) for the checks performed on this release and remaining limitations.

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/App` | SwiftUI screens, AppKit windows, preferences, and refresh coordination |
| `Sources/Core` | Source catalog, parsers, feed discovery, cache models, translation support, and geometry |
| `Tests` | Deterministic tests and small fixtures |
| `Resources` | App icon and artwork generation prompts |
| `docs` | User guide, screenshots, and release verification |

The internal executable name `LittleRadio`, bundle identifier `local.littleradio.desktop`, and `~/Library/Application Support/Little Radio` cache directory are retained for compatibility with earlier prototypes. The displayed product name is Catecho in every language.

## Data and limitations

The app stores preferences and cached editions on the Mac. It has no app analytics or account service. Requests go directly to the websites selected by the user, which receive ordinary web-request metadata such as the IP address.

RSS/Atom feeds are preferred. GitHub Trending, Anthropic's newsroom, and ESPN's public scoreboard use website interfaces that can change or fail. Website reading is bounded and heuristic; it does not execute JavaScript, sign into websites, or guarantee that every update is found. Missing dates, excerpts, statistics, or star counts are not invented. arXiv entries are labelled preprints. NBA scores are periodically fetched, not a guaranteed real-time stream.

The interface and icon follow Catecho's retro radio design. The icon was created with a built-in image-generation tool; its prompts are included in `Resources/CatechoIcon-prompt.txt`.

## Feedback

Use [GitHub Issues](https://github.com/Real-Etix/Catecho/issues) to report a problem or suggest an improvement. For bugs, include your macOS version, Catecho version, and steps to reproduce. Remove personal information from screenshots and logs.
