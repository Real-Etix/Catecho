# Verification · v0.7.0

Checked on an Apple Silicon Mac running macOS 15.5, 19 October 2026.

## Automated tests and review

`./test.sh` completed successfully with **286 PASS records** across parsing, model, interaction, placement, language, discovery, webpage, setup, login, Codex collection, rolling windows, monitor lifecycle, Zstandard decoding, streaming JSON projection, and session/title indexing programs.

History checks cover plain/compressed duplicate suppression, concatenated frames, corrupt/truncated archives, decoder window and output limits, huge irrelevant bodies, oversized usage rows, misleading nested fields, malformed JSON, and bounded retained memory. Review identified decoder slots retained by unreadable files; a regression reproduced the issue, and the corrected collector releases those contexts and resumes other archives.

Chat checks cover independent totals, expiry/future boundaries, persistence, source-folder resets, missing selections without fallback, optional title metadata, partial appends, renames, replacement, oversized lines, and bounded index work. Placement checks cover the widened tucked window, both screen edges, negative coordinates, drag clamps, and inverse antenna mapping. Final review found an Escape-routing issue; the app now lets the chat picker handle Escape while it is open. Focused re-review found no further issues.

The optional live-provider suite was not rerun for this feature. Six historical downloaded-feed checks remain excluded because their local fixtures are not in this repository.

## Native checks

- An isolated sample preview uses separate preferences/cache and disables login-item operations. Classic and Flat compact displays were visually checked, including English and Traditional Chinese. Existing static render coverage includes all three languages.
- The searchable chat selector filtered sample sessions. Selecting a chat changed the number, chart, input/output breakdown and tucked readout together. The selection survived appearance/language changes. Escape dismissed the picker while leaving the radio open in immediate interaction checks.
- The installed app opened tucked with the new live readout. It read local usage without a partial-history warning and exposed the chat selector. Exported preferences before and after installation were identical. The app was left tucked with its original all-chat scope.
- Native drag checks passed for no-op clicks, movement before release, final release coordinates, and a single placement commit. Tuck → reveal → tuck passed with a 190 × 126-point preview window and unchanged 374 × 416-point expanded footprint. Eight legacy edge/monitor geometry cases also passed.

## History coverage and performance

A controlled before/after replay at a fixed cutoff included 752 more compressed files. The unique events and 24-hour total were unchanged in that dataset: the added coverage did not invent extra usage. The false oversized-record and unsupported-Zstandard warnings were removed, with no previously counted event lost.

A separate read-only live diagnostic processed about 1.79 GB in 271 bounded polls in **34.02 seconds** wall time (21.73 seconds user / 3.41 seconds system), with peak RSS about **43 MB**. The next idle poll read **0 bytes**. These are observations on one Mac, not performance guarantees.

## Build and package

`./build.sh` produced **0.7.0, build 18**. Both built and installed bundles passed strict ad-hoc signature verification, and their executables matched byte-for-byte. The previous installed app was retained locally for rollback. The app-only ZIP passed its integrity check and every packaged file matched the build; a SHA-256 checksum accompanies the download. The bundled Zstandard license matches the vendored license, and the executable has no external Homebrew dependency.

The shell build uses the repository's existing local overlay for a duplicate SwiftBridging module map in this Mac's Command Line Tools installation. Native tests require WindowServer access. A SwiftPM manifest/linker failure was also reproduced on the unchanged base manifest; SwiftPM validation remains unavailable on this toolchain. The shell build and full shell test suite passed.

## Remaining limitations

- Local Codex log formats can change. Unsupported compression, corrupt archives, structural limits, unreadable files, mixed-schema reconciliation, missing cumulative baselines, and bounded-history limits can still produce incomplete totals; those conditions are surfaced.
- Chat totals cover retained local activity from the last 24 hours, not lifetime conversations. Optional titles may be absent; those sessions use a short ID. Subagents remain separate local sessions.
- Recorded bursts do not measure exact generation speed, subscription allowance, cost, or sessions on other machines/cloud workers. New nested session discovery can take roughly 15 seconds; optional titles refresh roughly every 30 seconds. Existing activity is polled about every second while visible and every five seconds while tucked.
- Runtime checks used macOS 15.5; the deployment target remains macOS 14. Actual logout/login, sleep/wake, multiple physical displays, and a full VoiceOver pass remain outstanding.
- Developer ID signing, notarization, Mac App Store submission, Intel builds, and automatic application updates are not included.

The repository and release exclude personal preferences, numeric history, source logs, chat titles, caches, local backups, and development-session data. Published monitor imagery uses sample numbers.
