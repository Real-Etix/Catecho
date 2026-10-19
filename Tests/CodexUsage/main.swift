import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { print("FAIL Codex usage: " + message); exit(1) }
    print("PASS Codex usage: " + message)
}

@main struct UsageTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static func stamp(_ offset: Double = -10) -> String { ISO8601DateFormatter().string(from: now.addingTimeInterval(offset)) }
    static func json(_ type: String, _ payload: [String: Any], at: Double = -10) -> String {
        let data = try! JSONSerialization.data(withJSONObject: ["type": type, "timestamp": stamp(at), "payload": payload], options: [.sortedKeys])
        return String(data: data, encoding: .utf8)! + "\n"
    }
    static func usage(_ input: Int, _ output: Int = 10) -> [String: Int] {
        ["input_tokens": input, "cached_input_tokens": input / 2, "output_tokens": output, "reasoning_output_tokens": output / 2]
    }
    static func meta(_ id: String, parent: String? = nil, at: Double = -1000) -> String {
        var p: [String: Any] = ["id": id, "timestamp": stamp(at)]
        if let parent { p["parent_thread_id"] = parent }
        return json("session_meta", p, at: at)
    }
    static func record(_ id: String, input: Int = 100, session: String = "s", at: Double = -10) -> String {
        json("token_usage_record", ["response_id": id, "thread_id": session, "usage": usage(input)], at: at)
    }
    static func count(_ total: Int, last: Int? = nil, at: Double = -10) -> String {
        var info: [String: Any] = ["total_token_usage": usage(total, total / 10)]
        if let last { info["last_token_usage"] = usage(last, last / 10) }
        return json("event_msg", ["type": "token_count", "info": info], at: at)
    }
    static func folder() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("CatechoUsage-" + UUID().uuidString)
        try! FileManager.default.createDirectory(at: u.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        return u
    }
    static func write(_ text: String, _ root: URL, _ name: String = "a.jsonl") {
        try! Data(text.utf8).write(to: root.appendingPathComponent("sessions/" + name))
    }
    static func append(_ text: String, _ root: URL, _ name: String = "a.jsonl") {
        let h = try! FileHandle(forWritingTo: root.appendingPathComponent("sessions/" + name)); defer { try? h.close() }
        try! h.seekToEnd(); try! h.write(contentsOf: Data(text.utf8))
    }
    static func settled(_ c: CodexUsageCollector, at: Date = now) async -> CodexUsageSnapshot {
        for _ in 0..<1000 { let s = await c.poll(now: at); if !s.isIndexing { return s } }
        fatalError("indexing did not settle")
    }
    static func main() async {
        if CommandLine.arguments.contains("--live") {
            let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CODEX_HOME"] ?? NSHomeDirectory() + "/.codex")
            let c = CodexUsageCollector(rootDirectory: root)
            let started = Date(); var bytes = 0; var polls = 0; var s = await c.poll()
            repeat { bytes += s.bytesRead; polls += 1; if !s.isIndexing { break }; s = await c.poll() } while polls < 1000
            let incremental = await c.poll()
            print("LIVE polls=\(polls) bytes=\(bytes) seconds=\(Date().timeIntervalSince(started)) files=\(s.filesScanned)/\(s.filesTotal) events=\(s.events.count) incrementalBytes=\(incremental.bytesRead) warning=\(s.warning ?? "none")")
            return
        }
        let root = folder(); defer { try? FileManager.default.removeItem(at: root) }
        let cache = root.appendingPathComponent("history.json")
        write(meta("s") + record("r1") + count(100, last: 100) + record("r1") + record("r2", input: 200), root)
        let c = CodexUsageCollector(rootDirectory: root, historyURL: cache)
        var s = await settled(c)
        check(s.events.count == 2 && s.events.reduce(0) { $0 + $1.usage.total } == 320, "modern records, repeated IDs and token_count do not double count")
        check(s.events.first!.usage.cachedInput == 50 && s.events.first!.usage.reasoning == 5, "cached and reasoning are subsets of raw total")
        let cacheDate = now.addingTimeInterval(-500)
        try! FileManager.default.setAttributes([.modificationDate: cacheDate], ofItemAtPath: cache.path)
        let idle = await c.poll(now: now)
        check(idle.bytesRead == 0 && !idle.isIndexing, "unchanged poll performs no log reads")
        let idleCacheDate = (try! FileManager.default.attributesOfItem(atPath: cache.path))[.modificationDate] as! Date
        check(abs(idleCacheDate.timeIntervalSince(cacheDate)) < 1, "unchanged poll does not rewrite the numeric cache")
        append(record("r3", input: 300).dropLast().description, root)
        s = await c.poll(now: now); check(s.events.count == 2, "partial trailing JSON is deferred")
        append("\n", root); s = await settled(c)
        check(s.events.count == 3 && s.bytesRead < 1000, "append completes partial JSON with incremental IO")
        write(meta("s") + record("r4", input: 400), root)
        s = await settled(c); check(s.events.count == 4, "truncation rescans while preserving numeric history")
        write(meta("s") + record("r4", input: 400), root, "copy.jsonl")
        try! FileManager.default.createDirectory(at: root.appendingPathComponent("archived_sessions"), withIntermediateDirectories: true)
        try! Data((meta("s") + record("r4", input: 400)).utf8).write(to: root.appendingPathComponent("archived_sessions/archive.jsonl"))
        s = await settled(c); check(s.events.count == 4, "copied and archived responses deduplicate")
        let replacement = root.appendingPathComponent("replacement.jsonl")
        try! Data((meta("s") + record("r5", input: 500)).utf8).write(to: replacement)
        try! FileManager.default.removeItem(at: root.appendingPathComponent("sessions/a.jsonl"))
        try! FileManager.default.moveItem(at: replacement, to: root.appendingPathComponent("sessions/a.jsonl"))
        s = await settled(c); check(s.events.count == 5, "rotation replaces the inode and preserves earlier history")
        let restarted = CodexUsageCollector(rootDirectory: root, historyURL: cache)
        s = await settled(restarted); check(s.events.count == 5, "restart restores numeric history and deduplicates rescans")
        let validHistory = try! Data(contentsOf: cache)
        try! FileManager.default.removeItem(at: root.appendingPathComponent("sessions"))
        try! FileManager.default.removeItem(at: root.appendingPathComponent("archived_sessions"))
        s = await c.poll(now: now); check(s.issue == .noLogs && s.events.count == 5, "unavailable logs preserve history with honest status")
        s = await c.poll(now: now.addingTimeInterval(86400)); check(s.events.isEmpty, "numeric history expires after 24 hours")

        let legacy = folder(); defer { try? FileManager.default.removeItem(at: legacy) }
        write(meta("legacy") + count(100, last: 20, at: -50) + count(100, last: 20, at: -45) + count(150, last: 50, at: -40) + count(10, last: 10, at: -30), legacy)
        let lc = CodexUsageCollector(rootDirectory: legacy)
        s = await settled(lc)
        check(s.events.reduce(0) { $0 + $1.usage.total } == 88, "legacy baseline uses last response, repeated snapshots are ignored and resets use last")
        write(meta("child", parent: "parent", at: -25) + count(200, last: 200, at: -50) + record("inherited", session: "parent", at: -50) + count(300, last: 100, at: -20) + record("child-r", input: 100, session: "child", at: -20), legacy, "child.jsonl")
        s = await settled(lc)
        check(s.events.filter { $0.sessionID == "child" }.reduce(0) { $0 + $1.usage.total } == 110, "child excludes inherited prefixes and favors actual response records")
        write(meta("compact") + json("compacted", ["compaction_response_id": "cr", "latest_token_usage_record": ["thread_id": "compact", "response_id": "cr", "usage": usage(40)]]) + record("cr", input: 40, session: "compact") + json("compacted", ["compaction_response_id": "marker-only"]), legacy, "compact.jsonl")
        s = await settled(lc)
        check(s.events.filter { $0.sessionID == "compact" }.reduce(0) { $0 + $1.usage.total } == 50, "standalone compaction usage counted once; marker alone adds nothing")
        write(meta("bounds") + record("too-old", session: "bounds", at: -86401) + record("edge", session: "bounds", at: -86400) + record("future", session: "bounds", at: 1), legacy, "bounds.jsonl")
        s = await settled(lc)
        check(s.events.contains { $0.id.contains("edge") } && !s.events.contains { $0.id.contains("too-old") || $0.id.contains("future") }, "24-hour boundaries are inclusive and future records are excluded")
        write(meta("giant") + json("response_item", ["unused": String(repeating: "x", count: 10_000_000)]) + record("after-giant", session: "giant"), legacy, "giant.jsonl")
        s = await lc.poll(now: now)
        check(s.isIndexing && s.bytesRead <= 8 * 1024 * 1024, "large files have bounded per-poll IO and indicate remaining work")
        s = await settled(lc)
        check(s.events.contains { $0.id.contains("after-giant") } && s.warning != nil, "oversized line is skipped with warning and following records survive")
        write(meta("bad") + "{broken json}\n" + record("good-after-bad", session: "bad"), legacy, "bad.jsonl")
        s = await settled(lc); check(s.events.contains { $0.id.contains("good-after-bad") } && s.warning != nil, "malformed lines report partial history and do not block valid records")
        let missing = CodexUsageCollector(rootDirectory: legacy.appendingPathComponent("absent"))
        s = await missing.poll(now: now); check(s.issue == .missingFolder, "missing source folder is distinguished")
        write("", legacy, "compressed.jsonl.gz")
        s = await settled(lc); check(s.warning != nil, "unsupported compression reports partial history")
        let unreadable = folder(); defer { try? FileManager.default.removeItem(at: unreadable) }
        write(meta("unreadable"), unreadable)
        try! FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: unreadable.appendingPathComponent("sessions/a.jsonl").path)
        s = await CodexUsageCollector(rootDirectory: unreadable).poll(now: now)
        check(s.issue == .unreadable, "unreadable logs are distinguished")
        let sourceUnavailable = root.appendingPathComponent("temporarily-missing")
        let savedCache = root.appendingPathComponent("saved-cache.json")
        try! validHistory.write(to: savedCache)
        let cachedMissing = CodexUsageCollector(rootDirectory: sourceUnavailable, historyURL: savedCache)
        s = await cachedMissing.poll(now: now)
        check(s.issue == .missingFolder && s.events.count == 5 && s.lastRecordedAt == now.addingTimeInterval(-10), "cached usage survives missing sources without changing recorded freshness")
        let baselines = folder(); defer { try? FileManager.default.removeItem(at: baselines) }
        write(meta("baseline") + count(100, at: -50) + count(150, at: -40) + count(10, at: -30) + count(20, at: -20), baselines)
        s = await settled(CodexUsageCollector(rootDirectory: baselines))
        check(s.events.reduce(0) { $0 + $1.usage.total } == 66 && s.warning != nil, "missing first/reset last-usage uses a baseline and warns without inventing past usage")
        let cancelled = CodexUsageCollector(rootDirectory: baselines)
        let task = Task { await cancelled.poll(now: now) }; task.cancel()
        s = await task.value
        check(s.bytesRead == 0 && s.isIndexing, "cancellation yields before log IO and preserves remaining-work state")
        s = await settled(cancelled); check(!s.events.isEmpty, "a later poll resumes after cancellation")
        write(meta("oversized-id") + record(String(repeating: "x", count: 300_000), session: "oversized-id") + record("after-id", session: "oversized-id"), baselines, "ids.jsonl")
        s = await settled(CodexUsageCollector(rootDirectory: baselines))
        check(s.events.filter { $0.sessionID == "oversized-id" }.count == 1 && s.warning != nil, "oversized opaque identifiers cannot expand retained numeric history")
        let cap = folder(); defer { try? FileManager.default.removeItem(at: cap) }
        write(meta("cap") + (0..<20_001).map { record("cap-\($0)", input: 1, session: "cap") }.joined(), cap)
        let capped = CodexUsageCollector(rootDirectory: cap, historyURL: cap.appendingPathComponent("numeric.json"))
        s = await settled(capped)
        check(s.events.count == 20_000 && s.warning != nil, "numeric history is bounded with an explicit partial-history warning")
        let cachedData = try! Data(contentsOf: cap.appendingPathComponent("numeric.json"))
        check(cachedData.count <= 8 * 1024 * 1024 && !String(decoding: cachedData, as: UTF8.self).contains("payload"), "atomic cache is bounded numeric data without rollout bodies")
        print("PASS all Codex usage collector tests")
    }
}
