# Verification · v0.5.0

Checked on an Apple Silicon Mac running macOS 15.5, 19 October 2026.

## Automated tests

`./test.sh` completed successfully with **194 PASS records** across the core, model, interaction, placement, language, discovery, discovery-model, webpage, setup, and login-adapter test programs.

The new setup checks cover first launch, interrupted setup, upgrade migration from all persisted preferences and valid cached editions, validation, completion persistence, language and research choices, fetch gating, selected-station warmup, replay, and skip. Migration regressions were reproduced before fixing them. The login adapter's 29 checks inject OS operations to verify enabled, disabled, pending approval, failure, retry, and installation-location states without changing real login items.

Six optional historical downloaded-feed checks are excluded because their local fixtures are not in this repository. This release did not run the full optional live-provider suite.

## Native interaction checks

A separately identified app with isolated preferences/cache was used for setup interaction checks. Its login operations were disabled.

- Classic and Flat retain the 374 × 416-point footprint. All three steps were inspected in English, with Simplified and Traditional Chinese language previews also checked.
- Topic switches, expandable research subjects, empty-selection validation, Back, Continue, Start reading, and skip worked. Return advances and Escape goes back; an initial Escape issue was reproduced and corrected with the Back button's native cancel shortcut.
- Finishing preserved the selected AI/research stations, physics subjects, and language. Live fetching showed the existing radio-wave loading state and produced a cached edition. Relaunch began tucked and did not repeat setup.
- The installed app migrated without showing setup. Every pre-existing preference matched its saved pre-update value. Its real macOS login status was displayed as enabled; this check did not toggle the user's existing registration.
- The final executable passed eight geometry cases and native drag/floating-panel/tuck → reveal → tuck diagnostics.

## Build and release package

`./build.sh` produced version **0.5.0, build 16**, using whole-module release optimization and ServiceManagement. Strict ad-hoc signature verification passed for both the built and installed bundles. The installed executable matched the build byte-for-byte.

The app-only ZIP passed its integrity check, and all bundle files matched the fresh build. A SHA-256 checksum accompanies the download.

## Remaining limitations

- The minimum deployment target is macOS 14; runtime checks here used macOS 15.5.
- Actual logout/login, sleep/wake, broader full-screen Spaces, multiple physical displays, and a complete VoiceOver pass remain outstanding. Login approval and failure paths were exercised through injected OS responses.
- Developer ID signing, notarization, Mac App Store submission, Intel builds, and automatic app updates are not included.
- Public sources may change or fail. Deterministic tests do not establish every provider's current availability.

The repository excludes personal preferences, source caches, build caches, local app backups, and development-session data. The setup screenshot shows an isolated test profile.
