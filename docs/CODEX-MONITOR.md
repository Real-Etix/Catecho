# Codex local activity

Enable **Codex** in the radio’s rear station switches. The channel dial then includes an e-paper usage display for all locally recorded Codex sessions, including subagent work. Nothing is uploaded. This station is optional and off by default.

| View | Large reading | Activity chart |
| --- | --- | --- |
| TOTAL | All recorded tokens for the selected chat, without a time expiry | Recent 24-hour activity, labeled separately |
| SEC | Tokens recorded in the last 60 seconds, divided by 60 | 60 one-second bins |
| MIN | Tokens recorded in the last 60 seconds | 60 one-minute bins |
| HR | Tokens recorded in the last hour | 24 one-hour bins |

Choose **All chats** in the Codex header to open a searchable chat selector. Select a chat to filter the number, chart and input/output details together. The list shows each session’s lifetime total from available local records, including old and inactive chats. Select **TOTAL** to show that total on the radio and antenna; SEC/MIN/HR keep their recent readings. The chart under TOTAL remains explicitly labeled recent 24-hour activity. A selected chat stays selected while idle. Subagents are listed as separate local sessions; parent history inherited by a child is excluded.

While tucked, a small e-paper readout beside the antenna follows the selected chat and time view. Click it to open the Codex station; the antenna tip still opens the radio and its base still drags. Rear settings offer **Token preview beside antenna** to restore the plain antenna. Source readings refresh about every five seconds while tucked; rolling values continue to age normally.

The slider and the radio’s previous/next buttons change the time view. Charts use the timestamp of each recorded burst. Empty bins stay empty. Input plus output forms the total; cached input and reasoning are subsets, available in the input/output tooltip and accessibility description.

Codex writes usage in batches. A display that refreshes once a second is not a measurement of each token’s generation time. These numbers are local activity, not account allowance, remaining subscription quota, or a bill. Sessions on other Macs or cloud workers are outside this scope.

## Local reading and storage

Catecho reads plain `.jsonl` and Zstandard-compressed `.jsonl.zst` files inside `sessions` and `archived_sessions` beneath `CODEX_HOME`, or `~/.codex` when that variable is unavailable. GUI apps may not inherit terminal environment variables, so the rear controls offer a folder chooser. Select the parent folder containing `sessions`.

The first scan can take a while on a large archive; the screen reports indexing progress. Afterward, the reader tails changed files in bounded chunks. It checks about once a second while the Codex screen is visible and every five seconds otherwise. Disabling the station stops monitoring.

When available, chat titles come from the optional `session_index.jsonl` under the chosen Codex folder. Catecho reads only its identity/title metadata, keeps titles in memory, and uses a short session ID if no title is available. It never derives chat names from message text. Title lookup is bounded and periodically refreshed; new names can take about 30 seconds to appear. Changing source folders clears the selected chat and names.

The parser selects numeric usage fields and opaque session/response identifiers. Large rows use a streaming projection, so a long conversation or compaction body does not hide numeric usage later in that row. Compressed records are decoded in memory; no decompressed log is written to disk. Each poll reads at most 8 MiB of source bytes and processes at most 8 MiB of plain/decompressed bytes, with at most two decoder contexts and an 8 MiB window per decoder. It does not read auth/config files, upload records, or save conversation bodies. A numeric cache under `~/Library/Application Support/Little Radio/Usage` retains at most 24 hours for recent charts. A separate `.lifetime.sqlite` ledger retains response identifiers, session identifiers, timestamps and numeric usage without a time expiry. Per-session aggregates and unique record IDs are updated in one transaction per poll, so replaying or archiving a record does not add it twice. Previously indexed totals survive source-file removal and app restarts. The existing numeric cache seeds the ledger during upgrade, then older available files are indexed. Changing source folders uses separate cache and ledger files.

Identified response records are deduplicated across plain, compressed and copied/archive logs. A readable plain sibling takes priority over its compressed copy. Older cumulative snapshots use deltas and inherited-child baselines. A large unrelated body alone no longer triggers “partial history.” Mixed schemas, missing baselines, corrupt/truncated archives, unsupported compression, structural limits, unreadable files, and numeric-history limits still do. Most coverage warnings describe gaps encountered during this scan; restarting rebuilds that assessment. Mixed-schema omissions are also recorded in the persistent ledger. Missing source folders keep cached records visibly unavailable rather than implying a live zero. Local log schemas can change across Codex versions. Lifetime means all available recorded usage, not a guarantee of complete history: deleted files that Catecho never indexed, unrecorded activity and older cumulative records without reliable baselines cannot be reconstructed. Initial totals may rise during backfill; the indexing indicator remains visible. Mixed-schema coverage warnings persist with the ledger. A ledger storage failure displays an unavailable lifetime reading while recent collection can continue. The ledger allows up to 10,000 sessions and 256 MiB with a 2 MiB SQLite page cache; exceeding a limit is reported explicitly.

## References

- [OpenAI app-server documentation](https://learn.chatgpt.com/docs/app-server): thread token notifications and account allowance are separate concepts.
- [ccusage Codex accounting notes](https://ccusage.com/guide/codex/): cumulative snapshots, inherited subagent histories, compaction, and differences between local records and account usage.

No external monitoring package or daemon is bundled.
