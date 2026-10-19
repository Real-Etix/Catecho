# Verification · v0.8.0

Checked on an Apple Silicon Mac running macOS 15.5, 19 October 2026.

## Automated checks and review

`./test.sh` completed successfully with **307 PASS records** and no failures. Existing source, setup, login, translation, placement, history decoder and rolling-window coverage remains in the suite.

The new lifetime suite checks records older than 24 hours, duplicate files, repeated polls, restart/replay idempotency, source removal, rolling expiry, new appends, future-record exclusion, child/parent separation, old-cache migration, corrupted storage, compressed old records, legacy/modern reconciliation, durable mixed-format warnings, ordinary paired notifications, explicit session limits and integer saturation. Monitor tests distinguish an unavailable selected chat from a real zero while preserving another chat's saved total; idle chats retain lifetime totals and the selection never falls back to all chats. Combined warnings are translated in both Chinese scripts.

Independent review identified mixed-history warning gaps and scope-specific unavailable/zero errors. Regression checks reproduced both before the fixes and passed afterward. A focused re-review approved the final implementation with no remaining actionable findings.

The optional live-provider suite was not rerun for this feature. Six historical downloaded-feed checks remain excluded because their local fixtures are not in this repository.

## Native and live checks

- Classic/English and Flat/Traditional Chinese TOTAL layouts were visually checked in an isolated sample app. The lifetime headline, input/output details, chat list and tucked antenna readout agreed. A sample chat with no recent activity retained its lifetime total while the explicitly labeled recent 24-hour chart remained empty.
- The final native drag checks and tuck → reveal → tuck check passed. The compact window remains 190 × 126 points and the full radio remains 374 × 416 points. Eight edge/monitor geometry cases passed.
- The installed app backfilled older plain/compressed local records into its lifetime ledger. A read-only database audit verified that every session aggregate matched the sum of its unique stored usage records. Older mixed-format histories retained visible partial-coverage warnings; the app does not promise exact usage for missing history.
- Preferences immediately after installation exactly matched the previous version. TOTAL was then selected through the installed UI; a second comparison found changes only to `codexWindow` and the antenna placement coordinates during live interaction. The installed radio was left tucked with its lifetime readout, original language, appearance, source choices and chat scope.

## Build and package

`./build.sh` produced **0.8.0, build 19**. Built and installed bundles passed strict ad-hoc signature verification and their executables matched byte-for-byte. The previous installed app was retained locally for rollback. The app-only ZIP passed its integrity check and all five packaged files matched the tested build; a SHA-256 checksum accompanies the release.

The executable uses macOS's SQLite library and the existing statically linked Zstandard decoder. It has no Homebrew runtime dependency. The repository's existing Command Line Tools overlay remains in use. The earlier SwiftPM manifest/linker limitation on this Mac's toolchain remains; verification used the shell build and test suite.

## Limits

- Lifetime means recorded local usage, with no age expiry. Deleted files never indexed by Catecho, unrecorded usage, unreliable cumulative baselines, unsupported/corrupt records and mixed-format omissions can leave gaps. Subagents are separate sessions.
- The numeric SQLite ledger is capped at 10,000 sessions and 256 MiB with a 2 MiB page cache. A storage error or limit produces an unavailable lifetime display; recent collection can continue. The recent chart cache still retains up to 24 hours.
- No prompts, conversation bodies or chat titles are written to the ledger. It stores numeric usage, opaque identifiers and timestamps. Optional title metadata stays in memory. Nothing is uploaded.
- Counts do not measure exact generation speed, subscription allowance, monetary cost, or other computers/cloud workers.
- Runtime checks used macOS 15.5; the deployment target remains macOS 14. Actual logout/login, sleep/wake, multiple physical displays and a full VoiceOver pass remain outstanding.
- Developer ID signing, notarization, Mac App Store submission, Intel builds and automatic app updates are not included.

Published artifacts exclude personal preferences, numeric history, chat titles, source logs, local backups and development-session data. Published monitor imagery uses sample data.
