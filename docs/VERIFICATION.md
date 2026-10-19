# Verification · v0.4.11

Checked on an Apple Silicon Mac running macOS 15.5, 19 October 2026.

## Automated tests

`./test.sh` completed successfully from this repository with **132 PASS records** across the core, model, interaction, placement, language, discovery, discovery-model, and webpage test programs.

The suite covers source parsing, safe links, absent metadata, source interleaving, cached editions, configuration persistence, cancellation, refresh coordination, custom website discovery, translation-cache separation, antenna gestures, radio turns, and placement geometry. Six optional historical downloaded-feed checks are not included because their local development fixtures are not part of this repository. No live provider run was performed for this packaging release.

## Build and release package

- A fresh `./build.sh` completed successfully and produced `dist/Catecho.app`, version 0.4.11, build 15, with the radio icon declared in its bundle metadata.
- `codesign --verify --deep --strict` passed for the ad-hoc signature.
- The built executable passed eight desktop edge/monitor geometry cases and the native smoke diagnostics for drag tracking, floating-window properties, and tuck → reveal → tuck.
- The app-only ZIP passed its integrity check. All four bundle files match the fresh build byte-for-byte, and a SHA-256 checksum accompanies the download.

## Scope

The Swift sources, tests, and artwork match the previously installed v0.4.11 prototype. This repository preparation changes the build output to `dist/Catecho.app` and adds public documentation and sample screenshots. It does not change runtime behavior.

The repository excludes local preferences, source caches, build caches, historical app backups, and development-session screenshots. The two included radio screenshots are sample editions. The app icon was previously inspected at small and large sizes in Finder.

## Remaining limitations

- The minimum deployment target is macOS 14, but this release's checks ran on macOS 15.5. Runtime testing on macOS 14 and other Mac hardware remains outstanding.
- Broader full-screen Spaces, multiple physical monitors, sleep/wake, and VoiceOver testing remains outstanding.
- The build is locally ad-hoc signed. Developer ID signing, notarization, and Mac App Store submission are not completed.
- Public feeds and website interfaces can change or fail. Automated deterministic tests do not establish current availability of every provider.
