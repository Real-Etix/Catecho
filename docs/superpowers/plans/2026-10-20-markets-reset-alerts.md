# Markets and Reset Alerts Implementation Plan

**Goal:** Add financial news, an editable US-stock watchlist and one-time alerts for Tibo reset announcements.
**Architecture:** Extend the station catalog and shared feed/cache path; isolate quote parsing and reset validation/deduplication in Core, and native notification delivery in App.
**Tech Stack:** Swift, SwiftUI, AppKit, Foundation, UserNotifications; macOS 14+.

## Global constraints

Use the existing radio appearance and three UI languages. No paid backend or embedded API keys. Preserve existing preferences; never fabricate prices or account reset status. Keep user-specific tickers out of committed defaults.

- [x] Add selectable catalog entries and backwards-compatible watchlist/alert configuration. Verify missing-station regression first.
- [x] Implement bounded public quote fetching, validation, partial failures and cached fallback; prove parser and watchlist coverage with offline fixtures.
- [x] Implement the source-linked reset API reader and persistent, quiet-first-run alert ledger; test duplicate, stale, future, restart and malformed-source behavior.
- [x] Wire model refresh cadence, all-watchlist pagination, native notification permissions and rear-panel controls. Use existing molded labels, field and switch styles.
- [x] Render and exercise native quote, news, reset and settings views. Run core/model/language/interaction checks and live source checks.
- [x] Build/install with a rollback copy; enable only the requested new preferences in local preferences, inspect them in the app and verify existing preferences remain. Document verification and commit.
