# Lifetime Codex totals implementation plan

**Goal:** Show cumulative recorded tokens for every local chat, including older sessions.
**Architecture:** A numeric SQLite identity ledger and session aggregates complement the existing rolling cache. The collector owns storage; the model selects lifetime or recent readings; the existing radio and antenna share that selection.
**Tech stack:** SwiftUI/AppKit, Foundation, macOS SQLite3 and the existing Zstandard decoder.

## Constraints
- No cloud service, message bodies or persisted chat titles.
- Existing 8 MiB input/output budgets and 24-hour chart retention remain.
- Ledger: 10,000 sessions, 256 MiB database, bounded SQLite page cache, per-poll transactions.
- Failed or incomplete coverage is visible. No reconstructed usage for missing source history.
- Keep the 190 × 126 tucked and 374 × 416 expanded footprints.

## Task 1: Durable accounting
- [x] Add `Tests/CodexLifetime/main.swift` for old records, idempotent replay, persistence/deletion, cache migration, independent sessions, mixed schemas, future records and unavailable storage. Run a focused build and observe the missing-feature failure.
- [x] Add `Sources/Core/CodexLifetimeStore.swift`: `init(url: URL?) throws`, `begin()`, `record(_:)`, `markModern(_:)`, `finish() -> [CodexSessionSummary]`, `modernSessions`. Store response identities and per-session totals in one SQLite transaction. Preserve aggregate timestamps and clamp arithmetic. Throw on failures/limits.
- [x] Extend `CodexUsageSnapshot` with optional lifetime summaries. In `CodexUsageCollector`, open the store once, migrate valid cached records, insert old events before the rolling-age guard, reconcile legacy contributions, and commit before each snapshot. Preserve a clear failure state and continue recent collection if storage fails.
- [x] Run lifetime and existing collector suites; fix failures before proceeding.

## Task 2: Lifetime UI
- [x] Add TOTAL to `CodexUsageWindow` and model helpers for scoped lifetime usage and availability. Default new preferences to TOTAL; preserve existing preferences. Chat lists use lifetime summaries; a missing selection never becomes all chats.
- [x] Update picker, radio and compact preview, retaining the recent chart with an explicit label. Localize new copy in English, Simplified and Traditional Chinese. Add representative older sample usage.
- [x] Extend monitor/window tests for persistence, independent lifetime totals, idle preservation and no selected-chat fallback.

## Task 3: Delivery
- [x] Run complete tests, optimized build, code review and sample native checks. Fix any review findings and verify their regressions.
- [x] Document coverage and storage. Install with a rollback copy, compare preferences and select TOTAL for the requested live preview.
- [x] Prepare the verified app-only package and checksum for the established public beta workflow; commit and publish the reviewed source with matching assets.
