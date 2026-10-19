# Codex Glance Implementation Plan

> Use inline execution for the monitor extension and review the integrated change before delivery.

**Goal:** Keep local token activity visible while tucked and allow tracking individual chats.
**Architecture:** Pure session summaries/filter → bounded optional title index → monitor scope state → shared reading in radio and compact e-paper view. Geometry maps the original antenna anchor to the wider tucked view without changing stored coordinates.
**Tech Stack:** Existing SwiftUI/AppKit/Foundation, no additional dependency.

## Global constraints
- Existing 24-hour numeric retention, source format coverage, deduplication and opt-in remain.
- Titles stay in memory; read only session_index.jsonl, never prompt bodies or auth files.
- Selected opaque ID persists, resets on source change, and never silently becomes all chats.
- Plain antenna is 54 × 126; preview window is 190 × 126; expanded radio remains 374 × 416. Respect both edges and monitor bounds.

### Task 1: Chat summaries and title metadata
- [x] Add deterministic checks for session filtering, 24-hour boundaries, per-session totals and title fallback; optional index missing/append/replace/oversize/malformed handling.
- [x] Add Sources/Core/CodexSessions.swift: summaries grouped by sessionID, stable recent ordering and clamped aggregates. A separate actor reads at most 2 MiB of optional JSONL index per refresh, lines <=64 KiB, IDs <=256 bytes and names <=256 characters, at most10k names. Refresh at most every30s; return empty mapping when root index is missing.
- [x] Add monitor selectedSessionID/showEdgePreview preferences, scopedEvents/sessions/title helpers; title task tied to collector lifecycle. Add selection persistence and root-change reset tests.

### Task 2: Compact view and scoped screen
- [x] Add geometry assertions for widened tucked window and inverse antenna mapping on both edges, negative screen coordinates and drag clamp.
- [x] Add custom ivory/sage chat-search popover and CodexEdgePreview using existing material tokens, concise labels and native accessibility.
- [x] Update EdgeTab and DesktopController sizing/hit regions so preview opens Codex, antenna still pulls/drags, preference controls visibility. Update CodexUsageView to use scoped events everywhere and select scope in its header. Add rear preview switch.
- [x] Localize all new labels; add sample-only render coverage for both modes, per-chat view, empty/partial states and compact preview.

### Task 3: Verification and delivery
- [x] Focused tests then complete suite and optimized build; inspect rendered/native results and fix clipping or behavior.
- [x] Review history cleanup and new scope/geometry/lifecycle changes; preserve local settings while installing.
- [x] Update user/verification docs and prepare v0.7.0 build18 ZIP/checksum for the existing public beta workflow. No personal logs, titles or usage in published artifacts.
