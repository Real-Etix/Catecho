# Codex History Coverage Implementation Plan

> Use subagent-driven-development for the isolated codec and independent review; root owns projection/collector integration. Continue within the user's authorized fix.

**Goal:** Recover recorded token usage from Zstandard archives and large records while retaining truthful warnings.
**Architecture:** Vendored upstream decompressor → bounded Swift streaming adapter → incremental line projector → existing numeric collector/deduplication.
**Tech Stack:** SwiftUI/AppKit/Foundation, Swift + small C bridge, pinned Zstandard 1.5.7 decompression-only BSD distribution, macOS 14+.

## Constraints
- Preserve numeric-only local persistence, read-only source logs, existing preferences and radio UI.
- Per poll at most 8 MiB compressed/plain source input and 8 MiB decompressed output; bounded 64 candidate discovery/metadata; 24h numeric history.
- Do not double-count copies; preserve actual record timestamps and input/output subset semantics.
- Never silently accept corrupt/truncated archives or unavailable usage as complete.

### Task 1: Portable Zstandard stream (isolated agent)
Read .superpowers/history-coverage/codec-brief.md. Own Vendor/Zstd, Sources/Core/CodexZstd.swift, Tests/CodexZstd, Package.swift, toolchain.sh and only dependency-link plumbing in build.sh/test.sh. Tests first; pinned upstream source/license/provenance; no runtime subprocess/Homebrew dependency. Return adapter to root and commit owned files.

### Task 2: Large-record projection and collector integration (root)
- Add failing fixtures for >8 MiB compaction with numeric fields after a discarded body, irrelevant large records, escaped quotes/key ordering, chunk boundaries, malformed tails, and bounded retained memory.
- Implement CodexJSONProjection.swift using a bounded streaming JSON grammar with schema-selected values. Keep ordinary small-line fast path; switch to projection above 256 KiB.
- Integrate .jsonl.zst discovery/continuations; plain sibling precedence; keep 8 MiB source/output budgets, <=2 active decoder states and numeric-only cache; truncation/corruption/resume/replacement tests.
- Verify dedup across compressed/plain/archive copies, no false warnings for irrelevant large payloads, actual local archive totals vs plain-only baseline, and flag remaining genuine gaps.

### Task 3: Verification and delivery
- Focused RED/GREEN, complete test suite, release build/strict signature, independent review and fixes.
- Compare local scan totals/warnings and memory/IO; inspect native installed state and preserve prefs on update.
- Update codec licensing/docs and warning translations; app 0.6.1 build 18; safe install and GitHub beta with ZIP+checksum.
