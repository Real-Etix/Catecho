# Belly Token Bot Implementation Plan

**Goal:** Implement the approved Catecho bot with a top-centre antenna and live retractable token dashboard.

**Architecture:** A pure BotGeometry value supplies the synchronized mechanical pose and window bounds. Native SwiftUI artwork uses that pose. DesktopController reserves and releases window space without changing the saved antenna anchor. CodexMonitorModel remains the source of readings.

**Tech Stack:** SwiftUI, AppKit, Swift, macOS 14+; no new dependencies.

## Constraints

- Preserve existing preferences, local usage storage, radio view and antenna fallback.
- Match Classic/Flat and all three supported UI languages.
- Only user-triggered motion, with Reduce Motion and accessibility actions.
- Work in the current project checkout on `feat/belly-token-bot`.

## Tasks

- [x] Add regression tests in `Tests/Bot/main.swift` for bounded inward expansion on both edges, drag roundtrips, grip alignment and gesture direction. Run with `swiftc` through `toolchain.sh`; verify the missing feature fails before adding `Sources/Core/BotGeometry.swift`.
- [x] Add `Sources/App/TokenBotArtwork.swift` for the cream shell, centred aerial, telescopic arms and custom glove shapes. Add `Sources/App/TokenBotView.swift` for live readings, accessible click/pull controls and the base drag region. Use one animatable progress value; derive every moving position from it.
- [x] Integrate `EdgeTab`, RadioModel and DesktopController. Reserve the expanded native frame before opening; release it after the 280 ms close, cancelling stale completions. Keep the 54 × 126 antenna anchor format. Add bot-aware native smoke checks and a `--render-bot` sample renderer.
- [x] Localize new copy and update the user guide. Run `bash test.sh`, `bash build.sh`, native smoke and rendering checks. Exercise isolated preview expansion/reversal, base drag, antenna reveal, Escape and both appearances. Review implementation before installing.
- [x] Install the verified bundle with a rollback copy; compare installed and built binaries and verify preserved preferences. Leave the compact bot available to try.
