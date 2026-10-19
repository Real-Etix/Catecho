# Codex local activity

Enable **Codex** in the radio’s rear station switches. The channel dial then includes an e-paper usage display for all locally recorded Codex sessions, including subagent work. Nothing is uploaded. This station is optional and off by default.

| View | Large reading | Activity chart |
| --- | --- | --- |
| SEC | Tokens recorded in the last 60 seconds, divided by 60 | 60 one-second bins |
| MIN | Tokens recorded in the last 60 seconds | 60 one-minute bins |
| HR | Tokens recorded in the last hour | 24 one-hour bins |

Choose **All chats** in the Codex header to open a searchable chat selector. Select a chat to filter the number, chart and input/output details together. The list shows sessions with recorded activity in the last 24 hours and each session’s 24-hour total. A selected session stays selected when it becomes idle or ages out; its current reading becomes zero. Subagents are listed as separate local sessions. This is not a lifetime conversation total.

While tucked, a small e-paper readout beside the antenna follows the selected chat and time view. Click it to open the Codex station; the antenna tip still opens the radio and its base still drags. Rear settings offer **Token preview beside antenna** to restore the plain antenna. Source readings refresh about every five seconds while tucked; rolling values continue to age normally.

The slider and the radio’s previous/next buttons change the time view. Charts use the timestamp of each recorded burst. Empty bins stay empty. Input plus output forms the total; cached input and reasoning are subsets, available in the input/output tooltip and accessibility description.

Codex writes usage in batches. A display that refreshes once a second is not a measurement of each token’s generation time. These numbers are local activity, not account allowance, remaining subscription quota, or a bill. Sessions on other Macs or cloud workers are outside this scope.

## Local reading and storage

Catecho reads plain `.jsonl` and Zstandard-compressed `.jsonl.zst` files inside `sessions` and `archived_sessions` beneath `CODEX_HOME`, or `~/.codex` when that variable is unavailable. GUI apps may not inherit terminal environment variables, so the rear controls offer a folder chooser. Select the parent folder containing `sessions`.

The first scan can take a while on a large archive; the screen reports indexing progress. Afterward, the reader tails changed files in bounded chunks. It checks about once a second while the Codex screen is visible and every five seconds otherwise. Disabling the station stops monitoring.

When available, chat titles come from the optional `session_index.jsonl` under the chosen Codex folder. Catecho reads only its identity/title metadata, keeps titles in memory, and uses a short session ID if no title is available. It never derives chat names from message text. Title lookup is bounded and periodically refreshed; new names can take about 30 seconds to appear. Changing source folders clears the selected chat and names.

The parser selects numeric usage fields and opaque session/response identifiers. Large rows use a streaming projection, so a long conversation or compaction body does not hide numeric usage later in that row. Compressed records are decoded in memory; no decompressed log is written to disk. Each poll reads at most 8 MiB of source bytes and processes at most 8 MiB of plain/decompressed bytes, with at most two decoder contexts and an 8 MiB window per decoder. It does not read auth/config files, upload records, or save conversation bodies. A numeric cache under `~/Library/Application Support/Little Radio/Usage` retains at most 24 hours and is bounded by event count and file size. Changing source folders uses a separate cache.

Identified response records are deduplicated across plain, compressed and copied/archive logs. A readable plain sibling takes priority over its compressed copy. Older cumulative snapshots use deltas and inherited-child baselines. A large unrelated body alone no longer triggers “partial history.” Mixed schemas, missing baselines, corrupt/truncated archives, unsupported compression, structural limits, unreadable files, and numeric-history limits still do. Coverage warnings describe gaps encountered during this scan; restarting rebuilds that assessment. Missing source folders keep cached records visibly unavailable rather than implying a live zero. Local log schemas can change across Codex versions, and data that Codex never recorded cannot be reconstructed.

## References

- [OpenAI app-server documentation](https://learn.chatgpt.com/docs/app-server): thread token notifications and account allowance are separate concepts.
- [ccusage Codex accounting notes](https://ccusage.com/guide/codex/): cumulative snapshots, inherited subagent histories, compaction, and differences between local records and account usage.

No external monitoring package or daemon is bundled.
