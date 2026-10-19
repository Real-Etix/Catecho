# Codex Monitor Implementation Plan

> **For agentic workers:** Use subagent-driven-development for the collector and a final independent review; preserve disjoint ownership and run meaningful tests before completion.

**Goal:** Show recorded Codex token activity for all local sessions in Catecho's retro radio.
**Architecture:** A Foundation collector owns incremental parsing, deduplication and bounded numeric history. An observable app model controls polling; a SwiftUI screen presents rates, totals and a chart. RadioModel routes the local station separately from network feeds.
**Tech Stack:** SwiftUI, AppKit, Foundation, existing Swift shell toolchain; macOS 14+; no new third-party dependency.

## Global constraints
- Preserve existing preferences, news behavior, Classic/Flat materials, three UI languages, and 374 × 416-point footprint.
- Never persist prompt/response bodies, read Codex auth/config files, or modify Codex session contents.
- Total = input + output; cached and reasoning are subsets. Never infer account allowance or cost.
- Scope: all retained sessions on this Mac under the configured Codex home. Retain 24 hours of numeric history. Unsupported/missing records are explicit.

### Task 1: Incremental usage collector

**Ownership:** Sources/Core/CodexUsage.swift, Sources/Core/CodexUsageCollector.swift, Tests/CodexUsage/main.swift only.
**Interface:** CodexTokenUsage(input: Int64, cachedInput: Int64, output: Int64, reasoning: Int64), computed total; CodexUsageEvent(id: String, sessionID: String, recordedAt: Date, usage: CodexTokenUsage); CodexUsageSnapshot(events: [CodexUsageEvent], checkedAt: Date, lastRecordedAt: Date?, isIndexing: Bool, filesScanned: Int, filesTotal: Int, issue: CodexUsageIssue?, warning: String?, bytesRead: Int). CodexUsageIssue cases missingFolder, noLogs, unreadable. actor CodexUsageCollector init(rootDirectory: URL, historyURL: URL? = nil), func poll(now: Date = Date()) async -> CodexUsageSnapshot. Sendable values.

- [ ] Write failing deterministic temporary-file tests. Include usage subsets, duplicate response IDs, duplicate/copy/archive files, advancing and repeated cumulative counters, resets, inherited parent prefixes, standalone compaction records, partial lines, append-only reads, truncation/rotation, restart history, history expiry, missing/read-error states, bounded giant lines, and time-window boundaries.
- [ ] Implement the core and collector against actual local event shapes, with no raw user content in fixtures. Prefer real per-response records when available without counting the same token_count event again; fallback to cumulative logs. Existing valid cache history must survive unavailable source folders without falsely claiming live freshness.
- [ ] Compile with source toolchain.sh, swiftc ${RADIO_FLAGS[@]} -parse-as-library Sources/Core/CodexUsage*.swift Tests/CodexUsage/main.swift -o .build-local/codex-usage-tests. Run tests and an opt-in read-only live diagnostic. Record initial scan, incremental bytes, memory/CPU observations and ambiguities. Keep IO bounded per poll, no UI work, and atomic bounded numeric cache writes.

### Task 2: App model and station routing

**Files:** Sources/App/CodexMonitorModel.swift; RadioModel.swift; DesktopController.swift; Sources/Core/RadioCore.swift; Tests/Model/main.swift; test.sh.
- [ ] Add .codex preset with local-usage subtitle; keep it off in defaults and preserve stored enabled lists.
- [ ] Add a model that starts the collector only after setup when the station is enabled; use one-second visible/five-second tucked checks, cancellation, folder selection, and fake preview data. Run IO off main actor. Keep old metrics during indexing and mark stale states honestly.
- [ ] Add failing routing checks: enabling only Codex generates zero FeedService requests; preparing ordinary stations still works; reception next/last/pending counts exclude Codex. Implement guards using a separate feedChannels computed list.

### Task 3: Radio screen and rear controls

**Files:** Sources/App/CodexUsageView.swift; RadioView.swift; RadioSettings.swift; Sources/Core/RadioLanguage.swift.
- [ ] Reuse the screen material and detent controls. SEC headline uses last60s.total/60; MIN uses last60s.total; HR uses last3600s.total. Chart windows are 60 one-second bins, 60 one-minute bins, and 24 one-hour bins respectively. Label ranges and averages, preserve zero bins/idle decay, and never interpolate fabricated events.
- [ ] Provide local scope/freshness, input/output details, indexing/empty/error states, accessible chart summary, Reduce Motion support, and all three UI languages.
- [ ] Add Codex folder chooser and privacy/measurement explanation on the back. Route monitor navigation through the existing previous/next hardware and keep the channel dial's behavior.

### Task 4: Verification and delivery

- [ ] Run deterministic tests, build, strict codesign, geometry and native smoke diagnostics. Inspect Classic/Flat, all languages, enable/disable, SEC/MIN/HR, unavailable logs, ongoing local Codex usage and idle decay in an isolated preview.
- [ ] Independent code review of accounting, concurrency, data privacy, routing and UI integration; resolve material findings and retest affected behavior.
- [ ] Document measurement semantics, limits and references. Safely install after checking for unsaved drafts, preserve preferences, enable the requested station through the UI, and verify real readings. Package, commit and update the established GitHub beta workflow after validation.
