# Codex glance and per-chat activity

Extend the authorized monitor with a tucked antenna readout and per-chat scope. Preserve the ivory/sage Classic and Flat materials, existing antenna pull/drag interaction, setup gating and local-only numeric cache.

The tucked window gains a small e-paper readout toward the screen interior while Codex monitoring and its preview preference are enabled. It shows the selected SEC/MIN/HR reading, scope, and an honest indexing/unavailable/partial state. Clicking it opens the Codex station. The original 54 × 126 antenna remains when disabled. A custom rear slide switch controls this preview; enabled by default for existing Codex users.

The radio header has an All chats / chosen-chat control. Its themed popover searches and selects sessions with recorded activity during the retained 24 hours; each row shows a title or short ID, full ID in help, and 24-hour total. The selected scope filters the headline, chart, subsets and tucked preview consistently, persists by opaque ID, resets on source-folder change, and never silently falls back to all chats if a chosen session has no recent records. Subagent sessions remain separately identifiable rather than inventing parent totals.

Titles are read only from the optional local session_index.jsonl (id/thread_name fields), never inferred from message bodies. The bounded reader retains names in memory, accepts an incremental append/replace, and degrades to short IDs when missing or malformed. No names or message bodies enter the numeric history cache. IDs remain stable across title changes. Monitoring remains opt-in and other source behavior is unchanged.

Tests cover scope isolation and expiry, all-chat aggregation, optional title reading and limits, selection persistence/reset, compact state labels, and expanded/collapsed geometry and drag roundtrips on either edge. Verify both appearances and Chinese UI in an isolated native preview, then safely install preserving preferences and publish the established app-only beta.
