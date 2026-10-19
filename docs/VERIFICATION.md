# Verification · v0.6.0

Checked on an Apple Silicon Mac running macOS 15.5, 19 October 2026.

## Automated tests and review

`./test.sh` completed successfully with **247 PASS records** across parsing, model, interaction, placement, language, discovery, webpage, setup, login, Codex collection, rolling windows, and monitor lifecycle programs.

The collector has 43 focused checks covering response-ID deduplication, legacy cumulative deltas and resets, inherited subagent histories, compaction, partial lines, rotation, unavailable sources, expiry, cache limits, and bounded directory/metadata/content work. Review identified three defects—invalid cumulative subsets, expiry not saved with an unavailable folder, and unbounded metadata discovery—which were reproduced, fixed, and independently re-reviewed.

Routing tests confirm a Codex-only configuration never requests a news feed or enters news reception scheduling. Window tests cover exact boundaries, future timestamps, real zero bins, and idle decay. Lifecycle tests cover setup gating, folder changes, retained preferences, disabling, and task ownership. The broad final review found no blocking issue.

The optional live-provider suite was not rerun for this feature. Six historical downloaded-feed checks remain excluded because their local fixtures are not in this repository.

## Native checks

- Isolated sample and live previews use separate preferences/caches and disable login-item operations. Classic/Flat and all three UI languages were rendered; English and Chinese layouts were visually checked.
- SEC/MIN/HR and previous/next hardware controls switched views. Real local activity changed while Codex sessions were running. Selecting a folder without logs cleared the old reading and displayed a dash with an explicit no-session state.
- The installed app opened tucked, preserved every preference before opt-in, and retained its enabled macOS login status. Codex was enabled through the rear switch and selected on the dial. Existing station/source/language/appearance/placement preferences were preserved; saving also serialized an empty default `webpageURLs` field for a legacy custom station.
- The installed Codex screen showed current readings and a truthful partial-history notice for unsupported/oversized local records. Accessibility output exposed input/output and their subsets, and the last-record timestamp.
- Eight native edge/monitor geometry cases passed. The 374 × 416-point footprint is unchanged.

## Performance and package

A read-only diagnostic replayed 1.62 GB across 230 local files in 194 bounded polls in **8.46 seconds**. Measured CPU time was 5.38 seconds user / 1.20 seconds system, with peak RSS about 92 MB. The next idle poll read **0 bytes**. These are observations on one Mac, not performance guarantees.

`./build.sh` produced **0.6.0, build 17**. Both built and installed bundles passed strict ad-hoc signature verification, and the installed executable matched the build byte-for-byte. The previous installed app was retained locally for rollback. The app-only ZIP passed its integrity check and all packaged files matched the build; its SHA-256 checksum accompanies the download.

## Remaining limitations

- Local Codex log formats can change. Unsupported compressed files, oversized records, mixed-schema reconciliation, and missing cumulative baselines can produce incomplete totals; those conditions are surfaced.
- Recorded bursts do not measure exact generation speed, subscription allowance, cost, or sessions on other machines/cloud workers. Discovery of a new nested session can take roughly 15 seconds; existing active logs are checked more frequently.
- Runtime checks used macOS 15.5; the deployment target remains macOS 14. Actual logout/login, sleep/wake, multiple physical displays, and a full VoiceOver pass remain outstanding.
- Developer ID signing, notarization, Mac App Store submission, Intel builds, and automatic application updates are not included.

The repository and release exclude personal preferences, numeric history, source logs, caches, local backups, and development-session data. The published monitor screenshot uses sample numbers.
