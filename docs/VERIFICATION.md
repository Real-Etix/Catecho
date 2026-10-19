# Verification · v0.9.2

Checked on 19 October 2026. This revision changes only glove artwork, adds enlarged glove renders to the sample renderer, and increments the app version to build 22.

- Release build and strict ad-hoc signature verification passed; the installed executable matches the built executable.
- The existing 1,818-pose geometry checks and native drag, display-reposition and compact/full-radio roundtrip checks passed. No new behavior tests were added for this artwork-only revision; the full offline suite last passed in v0.9.1.
- Reviewed Classic and Flat glove close-ups and compact/expanded native renders. Fingers form a connected tapered outline with curved separators; an opposed thumb and top cuff replace the previous stack of capsules.
- The installed Traditional Chinese app was checked with live readings. Both glove controls still expand/retract the belly, and the widget was left compact. Saved preferences exactly match the pre-update export. The previous app bundle is retained for rollback.

---

## Previous verification · v0.9.1

Checked on 19 October 2026 with the native macOS build.

- The original antenna footprint is restored: compact 54 × 126 points, extended 260 × 178 points. Its cream base grows from 42 × 26 to 216 × 78 points. The original chrome antenna artwork is reused; no large head or face remains.
- The final offline suite completed successfully with 308 PASS records. Geometry covers 1,818 intermediate poses, all screen corners on both edges, off-origin displays, glove attachment, deliberate pull gestures, and reservation/retraction continuity on both axes.
- Native smoke checks passed for base dragging, compact → extended → compact, delayed release during base tracking, full-radio round trips, and dragging a corrected reserved panel followed by display reposition and retraction. The review-found display-reposition jump was reproduced before the fix; its regression and native checks now pass. Follow-up review found no further actionable issues.
- Classic and Flat were rendered in all three languages at 0%, 50% and 100%. Intermediate content scales to fit the growing e-paper inset without clipped header/footer fragments.
- The isolated sample preview was checked with compact belly/glove clicks, inward glove pull, lower-rim dragging, Escape and antenna opening of the full radio. The sample chat's 4.1M reading agreed with the full radio. An attempted blank-area click was unavailable through the GUI tool, so no blank-area event-routing result is claimed.
- The installed app was checked in Traditional Chinese with the user's current seconds view and live local activity. Compact belly expansion and glove retraction worked; the original compact antenna was left visible. All saved preference values exactly matched the pre-update export.
- Build 0.9.1 (21) passed strict ad-hoc signature verification, and the installed executable matches the built executable. The preceding bundle is retained locally for rollback. Token accounting, fetching, login registration and storage formats are unchanged.

Reduce Motion uses the direct state-change path; the system preference was not changed during this revision. Live provider tests were not repeated because fetching is unchanged. Missing local Codex history still produces the existing partial-history indication.

---

## Previous verification · v0.9.0

Checked on 19 October 2026 with the native macOS build.

- The full offline suite passed with 308 PASS records. Focused bot checks also pass after the final placement fixes: both edges, off-origin displays, 202 attached-hand poses, gesture directions, reservation/release continuity, and dragging an expanded bot before closing.
- Native smoke checks pass for base dragging, compact → extended belly → compact, deferred resize during base tracking, and bot → full radio → bot. Compact and extended bot windows are 172 × 214 and 304 × 214 points.
- Classic and Flat were rendered in English, Simplified Chinese and Traditional Chinese at compact, intermediate and extended poses. The renderer uses a native hosting window so the AppKit drag region is represented correctly. Intermediate text fits the changing screen width.
- An isolated sample app was exercised with belly and glove clicks, inward and outward glove pulls (including a pull ending inside the glove), Escape, top-antenna reveal and return from the full radio. The sample’s 4.1M lifetime reading agreed with its full-radio reading.
- Native verification also caught a one-point frame shift caused by automatic hosting-view sizing. The controller now owns the window size exclusively, and the exact frame roundtrip check passes.
- Independent review found and verified fixes for opposite-edge jumps, retraction during base dragging, and the combination of expanded dragging and closing. No actionable findings remain.
- The installed app was exercised with live local tokens in Traditional Chinese. Its belly expanded and retracted correctly and its recorded total continued updating. All saved preference values exactly matched the pre-update export. The previous bundle was retained for rollback.
- Build: 0.9.0, build 20. Strict ad-hoc signature verification passed. No changes to token accounting, network fetching, stored preferences or login registration are required by this feature.

Reduce Motion takes the direct state-change path in SwiftUI and the native controller; the system-wide preference was not changed during verification. Live provider tests were not repeated because source fetching is unchanged.

---

## Previous verification · v0.8.0

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
