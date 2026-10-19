# Codex local activity

Enable **Codex** in the radio’s rear station switches. The channel dial then includes an e-paper usage display for all locally recorded Codex sessions, including subagent work. Nothing is uploaded. This station is optional and off by default.

| View | Large reading | Activity chart |
| --- | --- | --- |
| SEC | Tokens recorded in the last 60 seconds, divided by 60 | 60 one-second bins |
| MIN | Tokens recorded in the last 60 seconds | 60 one-minute bins |
| HR | Tokens recorded in the last hour | 24 one-hour bins |

The slider and the radio’s previous/next buttons change the time view. Charts use the timestamp of each recorded burst. Empty bins stay empty. Input plus output forms the total; cached input and reasoning are subsets, available in the input/output tooltip and accessibility description.

Codex writes usage in batches. A display that refreshes once a second is not a measurement of each token’s generation time. These numbers are local activity, not account allowance, remaining subscription quota, or a bill. Sessions on other Macs or cloud workers are outside this scope.

## Local reading and storage

Catecho reads JSONL files inside `sessions` and `archived_sessions` beneath `CODEX_HOME`, or `~/.codex` when that variable is unavailable. GUI apps may not inherit terminal environment variables, so the rear controls offer a folder chooser. Select the parent folder containing `sessions`.

The first scan can take a while on a large archive; the screen reports indexing progress. Afterward, the reader tails changed files in bounded chunks. It checks about once a second while the Codex screen is visible and every five seconds otherwise. Disabling the station stops monitoring.

The parser selects numeric usage fields and opaque session/response identifiers. It does not read auth/config files, upload records, or save conversation bodies. A numeric cache under `~/Library/Application Support/Little Radio/Usage` retains at most 24 hours and is bounded by event count and file size. Changing source folders uses a separate cache.

Identified response records are deduplicated across copied/archive logs. Older cumulative snapshots use deltas and inherited-child baselines. Mixed schemas, missing baselines, oversized records, unreadable files, and unsupported compressed rollouts are marked as partial history. Missing source folders keep cached records visibly unavailable rather than implying a live zero. Local log schemas can change across Codex versions.

## References

- [OpenAI app-server documentation](https://learn.chatgpt.com/docs/app-server): thread token notifications and account allowance are separate concepts.
- [ccusage Codex accounting notes](https://ccusage.com/guide/codex/): cumulative snapshots, inherited subagent histories, compaction, and differences between local records and account usage.

No external monitoring package or daemon is bundled.
