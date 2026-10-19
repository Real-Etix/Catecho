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
        let largeRows = folder(); defer { try? FileManager.default.removeItem(at: largeRows) }
        let hugeBody = String(repeating: "ignored ", count: 1_200_000)
        let hugeCompaction = "{\"payload\":{\"replacement_history\":\"" + hugeBody + "\",\"latest_token_usage_record\":{\"response_id\":\"large-compact\",\"thread_id\":\"large\",\"usage\":{\"input_tokens\":700,\"output_tokens\":30}}},\"timestamp\":\"" + stamp() + "\",\"type\":\"compacted\"}\n"
        write(meta("large") + hugeCompaction + record("large-compact", input: 700, session: "large") + json("response_item", ["unused": hugeBody]) + record("after-large", session: "large"), largeRows)
        let largeCollector = CodexUsageCollector(rootDirectory: largeRows)
        var largeSnapshot = await settled(largeCollector)
        check(largeSnapshot.warning == nil && largeSnapshot.events.count == 2 && largeSnapshot.events.reduce(0) { $0 + $1.usage.total } == 840, "oversized compaction retains usage without counting its duplicate or warning about unrelated bodies")
        append(String(hugeCompaction.dropLast()).replacingOccurrences(of: "large-compact", with: "large-partial"), largeRows)
        largeSnapshot = await settled(largeCollector)
        check(largeSnapshot.events.count == 2, "oversized partial rows wait for a terminating newline")
        append("\n", largeRows); largeSnapshot = await settled(largeCollector)
        check(largeSnapshot.events.count == 3 && largeSnapshot.warning == nil, "oversized projection survives polls and append boundaries")
        let compressedRoot = folder(); defer { try? FileManager.default.removeItem(at: compressedRoot) }
        let fixtureFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
        let numericArchive = try! Data(contentsOf: fixtureFolder.appendingPathComponent("numeric.jsonl.zst"))
        let largeArchive = try! Data(contentsOf: fixtureFolder.appendingPathComponent("large.jsonl.zst"))
        let tailArchive = try! Data(contentsOf: fixtureFolder.appendingPathComponent("no-newline.jsonl.zst"))
        func archive(_ data: Data, _ name: String) { try! data.write(to: compressedRoot.appendingPathComponent("sessions/" + name + ".jsonl.zst")) }
        archive(largeArchive, "large")
        let archiveCollector = CodexUsageCollector(rootDirectory: compressedRoot)
        var compressedSnapshot = await archiveCollector.poll(now: now)
        check(compressedSnapshot.isIndexing && compressedSnapshot.events.isEmpty && compressedSnapshot.bytesRead == largeArchive.count, "compressed output is bounded independently of small input and resumes next poll")
        compressedSnapshot = await settled(archiveCollector)
        check(compressedSnapshot.events.count == 2 && compressedSnapshot.events.reduce(0) { $0 + $1.usage.total } == 430 && compressedSnapshot.warning == nil, "compressed oversized compaction retains numeric usage after its body")
        archive(numericArchive + tailArchive, "concatenated")
        archive(numericArchive, "copy")
        write(meta("compressed") + record("z-one", input: 90, session: "compressed"), compressedRoot, "plain-copy.jsonl")
        compressedSnapshot = await settled(archiveCollector)
        check(compressedSnapshot.events.count == 5 && compressedSnapshot.warning == nil, "concatenated archives and a final row without newline decode and deduplicate plain copies")
        let archiveIdle = await archiveCollector.poll(now: now)
        check(archiveIdle.bytesRead == 0 && !archiveIdle.isIndexing, "completed compressed streams release their context and are not reread")
        archive(Data([0, 1, 2]), "preferred")
        write(meta("preferred") + record("preferred-plain", session: "preferred"), compressedRoot, "preferred.jsonl")
        compressedSnapshot = await settled(archiveCollector)
        check(compressedSnapshot.events.count == 6 && compressedSnapshot.warning == nil, "available plain sibling takes priority over a compressed sibling")
        archive(Data(numericArchive.prefix(numericArchive.count / 2)), "broken")
        compressedSnapshot = await settled(archiveCollector)
        check(compressedSnapshot.warning != nil, "truncated archive stops indexing with an explicit coverage warning")
        archive(numericArchive, "broken")
        compressedSnapshot = await settled(archiveCollector)
        check(compressedSnapshot.events.count == 6 && !compressedSnapshot.isIndexing, "replaced incomplete archive retries safely and deduplicates recovered responses")
        let manyCompressed = folder(); defer { try? FileManager.default.removeItem(at: manyCompressed) }
        for index in 0..<70 { try! largeArchive.write(to: manyCompressed.appendingPathComponent("sessions/\(index).jsonl.zst")) }
        let manyArchiveCollector = CodexUsageCollector(rootDirectory: manyCompressed)
        compressedSnapshot = await settled(manyArchiveCollector)
        check(compressedSnapshot.filesScanned == 70 && compressedSnapshot.events.count == 2 && compressedSnapshot.warning == nil, "many expanding archives finish with bounded contexts and shared response deduplication")
        let review = folder(); defer { try? FileManager.default.removeItem(at: review) }
        let firstCounts = ["input_tokens": 100, "cached_input_tokens": 0, "output_tokens": 10, "reasoning_output_tokens": 0]
        let nextCounts = ["input_tokens": 110, "cached_input_tokens": 50, "output_tokens": 20, "reasoning_output_tokens": 15]
        write(meta("nonuniform") + json("event_msg", ["type": "token_count", "info": ["total_token_usage": firstCounts]], at: -20) + json("event_msg", ["type": "token_count", "info": ["total_token_usage": nextCounts]], at: -10), review)
        let reviewedCache = review.appendingPathComponent("numeric.json")
        let reviewed = CodexUsageCollector(rootDirectory: review, historyURL: reviewedCache)
        var reviewedSnapshot = await settled(reviewed)
        check(reviewedSnapshot.events.count == 1 && reviewedSnapshot.events[0].usage.total == 20 && reviewedSnapshot.events[0].usage.cachedInput <= 10 && reviewedSnapshot.events[0].usage.reasoning <= 10 && reviewedSnapshot.warning != nil, "nonuniform cumulative changes preserve raw delta and validate subsets with warning")
        let nonuniformRestart = await settled(CodexUsageCollector(rootDirectory: review, historyURL: reviewedCache))
        check(nonuniformRestart.events == reviewedSnapshot.events, "validated cumulative deltas survive restart unchanged")
        try! FileManager.default.removeItem(at: review.appendingPathComponent("sessions"))
        try! FileManager.default.removeItem(at: review)
        try! FileManager.default.createDirectory(at: review, withIntermediateDirectories: true)
        // Keep the cache outside the unavailable source root to verify actual disk expiry.
        let retainedCache = FileManager.default.temporaryDirectory.appendingPathComponent("CatechoReviewCache-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: retainedCache) }
        let unavailableRoot = review.appendingPathComponent("absent")
        let encodedHistory: [String: Any] = ["version": 1, "events": [["id": "response:expiry", "sessionID": "expiry", "recordedAt": now.addingTimeInterval(-10).timeIntervalSinceReferenceDate, "usage": ["input": 10, "cachedInput": 5, "output": 2, "reasoning": 1]]]]
        try! JSONSerialization.data(withJSONObject: encodedHistory).write(to: retainedCache)
        let absent = CodexUsageCollector(rootDirectory: unavailableRoot, historyURL: retainedCache)
        reviewedSnapshot = await absent.poll(now: now)
        check(reviewedSnapshot.events.count == 1 && reviewedSnapshot.issue == .missingFolder, "missing source retains still-valid cached usage")
        reviewedSnapshot = await absent.poll(now: now.addingTimeInterval(86400))
        let expiredDisk = try! JSONSerialization.jsonObject(with: Data(contentsOf: retainedCache)) as! [String: Any]
        check(reviewedSnapshot.events.isEmpty && (expiredDisk["events"] as! [Any]).isEmpty, "missing source persists expiry pruning to the numeric cache")
        let many = folder(); defer { try? FileManager.default.removeItem(at: many) }
        for i in 0..<600 { write(meta("many-\(i)") + record("initial-\(i)", session: "many-\(i)"), many, "\(i).jsonl") }
        try! FileManager.default.createDirectory(at: many.appendingPathComponent("sessions/nested"), withIntermediateDirectories: true)
        let boundedDiscovery = CodexUsageCollector(rootDirectory: many)
        reviewedSnapshot = await boundedDiscovery.poll(now: now)
        check(reviewedSnapshot.isIndexing && reviewedSnapshot.filesTotal > 0 && reviewedSnapshot.filesTotal <= 64, "directory discovery is bounded and reports unfinished discovery")
        reviewedSnapshot = await settled(boundedDiscovery)
        check(reviewedSnapshot.events.count == 600 && reviewedSnapshot.filesTotal == 600, "bounded discovery eventually visits every retained rollout")
        for i in 0..<600 { append(record("append-\(i)", session: "many-\(i)"), many, "\(i).jsonl") }
        reviewedSnapshot = await boundedDiscovery.poll(now: now)
        let appendedInOnePoll = reviewedSnapshot.events.filter { $0.id.hasPrefix("response:append-") }.count
        check(appendedInOnePoll > 0 && appendedInOnePoll <= 64, "cached inventory limits per-poll metadata refresh candidates")
        reviewedSnapshot = await settled(boundedDiscovery, at: now.addingTimeInterval(16))
        // Routine background metadata cycles are bounded; allow one complete sweep.
        for _ in 0..<12 { reviewedSnapshot = await boundedDiscovery.poll(now: now.addingTimeInterval(16)) }
        check(reviewedSnapshot.events.count == 1200, "bounded metadata sweeps eventually observe appended usage")
        write(meta("nested") + record("nested-new", session: "nested"), many, "nested/new.jsonl")
        reviewedSnapshot = await boundedDiscovery.poll(now: now.addingTimeInterval(16))
        check(reviewedSnapshot.filesTotal == 600 && !reviewedSnapshot.events.contains { $0.id == "response:nested-new" }, "inventory is cached between refresh cycles for unchanged top directories")
        reviewedSnapshot = await settled(boundedDiscovery, at: now.addingTimeInterval(32))
        check(reviewedSnapshot.filesTotal == 601 && reviewedSnapshot.events.contains { $0.id == "response:nested-new" }, "periodic bounded refresh discovers nested additions")
        let activePath = many.appendingPathComponent("sessions/0.jsonl")
        try! FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(100)], ofItemAtPath: activePath.path)
        for _ in 0..<12 { _ = await boundedDiscovery.poll(now: now.addingTimeInterval(32)) }
        append(record("hot-append", session: "many-0"), many, "0.jsonl")
        for i in 600..<900 { write(meta("many-\(i)"), many, "\(i).jsonl") }
        reviewedSnapshot = await boundedDiscovery.poll(now: now.addingTimeInterval(32))
        check(reviewedSnapshot.isIndexing && reviewedSnapshot.events.contains { $0.id == "response:hot-append" }, "known active appends remain prompt during incremental discovery")
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
        check(s.events.contains { $0.id.contains("after-giant") }, "oversized unrelated line does not prevent following records")
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
        try! FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: unreadable.appendingPathComponent("sessions/a.jsonl").path)
        let restricted = unreadable.appendingPathComponent("sessions/restricted")
        try! FileManager.default.createDirectory(at: restricted, withIntermediateDirectories: true)
        try! Data(meta("restricted").utf8).write(to: restricted.appendingPathComponent("hidden.jsonl"))
        try! FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: restricted.path)
        let inaccessibleDirectory = await CodexUsageCollector(rootDirectory: unreadable).poll(now: now)
        try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: restricted.path)
        check(inaccessibleDirectory.issue == .unreadable, "directory enumeration failures retain unreadable source status")
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
        let limitedRestore = CodexUsageCollector(rootDirectory: cap.appendingPathComponent("absent"), historyURL: cap.appendingPathComponent("numeric.json"))
        s = await limitedRestore.poll(now: now)
        check(s.events.count == 20_000 && s.warning != nil, "cache limit provenance survives restart when source logs are unavailable")
        var corrupt = try! JSONSerialization.jsonObject(with: validHistory) as! [String: Any]
        var corruptEvents = corrupt["events"] as! [[String: Any]]
        var corruptUsage = corruptEvents[0]["usage"] as! [String: Any]
        corruptUsage["cachedInput"] = -1; corruptUsage["reasoning"] = 1000
        corruptEvents[0]["usage"] = corruptUsage; corrupt["events"] = corruptEvents
        let corruptURL = root.appendingPathComponent("invalid-subsets.json")
        try! JSONSerialization.data(withJSONObject: corrupt).write(to: corruptURL)
        s = await CodexUsageCollector(rootDirectory: sourceUnavailable, historyURL: corruptURL).poll(now: now)
        check(s.events.count == 4 && s.warning != nil, "invalid cached token subsets are rejected with partial-history warning")
        print("PASS all Codex usage collector tests")
    }
}
