import Foundation

@main struct LifetimeTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static func check(_ value: Bool, _ label: String) { guard value else { fatalError(label) }; print("PASS lifetime: " + label) }
    static func row(_ type: String, _ payload: [String: Any], age: Double) -> String {
        let date = ISO8601DateFormatter().string(from: now.addingTimeInterval(-age))
        return String(data: try! JSONSerialization.data(withJSONObject: ["type": type, "timestamp": date, "payload": payload]), encoding: .utf8)! + "\n"
    }
    static func meta(_ id: String, age: Double = 900_000, parent: String? = nil) -> String {
        var p = ["id": id, "timestamp": ISO8601DateFormatter().string(from: now.addingTimeInterval(-age))]
        if let parent { p["parent_thread_id"] = parent }
        return row("session_meta", p, age: age)
    }
    static func record(_ id: String, _ session: String = "chat", _ input: Int = 100, age: Double) -> String {
        row("token_usage_record", ["response_id": id, "thread_id": session, "usage": ["input_tokens": input, "output_tokens": 10, "cached_input_tokens": 50, "reasoning_output_tokens": 5]], age: age)
    }
    static func settled(_ c: CodexUsageCollector, at: Date = now) async -> CodexUsageSnapshot {
        for _ in 0..<1000 { let s = await c.poll(now: at); if !s.isIndexing { return s } }; fatalError("Did not settle")
    }
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CatechoLifetime-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let log = root.appendingPathComponent("sessions/a.jsonl"), cache = root.appendingPathComponent("numeric.json")
        let text = meta("chat") + record("old", age: 300_000) + record("new", "chat", 200, age: 10)
        try Data(text.utf8).write(to: log)
        let collector = CodexUsageCollector(rootDirectory: root, historyURL: cache)
        var s = await settled(collector)
        check(s.events.count == 1 && s.lifetimeSessions?.first?.usage.total == 320, "old usage contributes to lifetime while the recent cache stays bounded")
        try Data(text.utf8).write(to: root.appendingPathComponent("sessions/copy.jsonl"))
        s = await settled(collector)
        check(s.lifetimeSessions?.first?.usage.total == 320, "duplicate files and repeated polls do not inflate lifetime")
        s = await settled(CodexUsageCollector(rootDirectory: root, historyURL: cache))
        check(s.lifetimeSessions?.first?.usage.total == 320, "restart and full replay are idempotent")
        try FileManager.default.removeItem(at: root.appendingPathComponent("sessions"))
        s = await settled(CodexUsageCollector(rootDirectory: root, historyURL: cache), at: now.addingTimeInterval(200_000))
        check(s.events.isEmpty && s.lifetimeSessions?.first?.usage.total == 320 && s.issue == .noLogs, "saved totals survive source removal and rolling expiry with unavailable status")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        try Data((text + record("append", age: 0) + record("future", age: -100)).utf8).write(to: log)
        s = await settled(CodexUsageCollector(rootDirectory: root, historyURL: cache))
        check(s.lifetimeSessions?.first?.usage.total == 430, "new records extend saved totals and future records are excluded")
        let child = meta("child", age: 50, parent: "chat") + record("old", age: 300_000) + record("child-only", "child", 40, age: 20)
        try Data(child.utf8).write(to: root.appendingPathComponent("sessions/child.jsonl"))
        s = await settled(CodexUsageCollector(rootDirectory: root, historyURL: cache))
        check(s.lifetimeSessions?.first(where: { $0.id == "child" })?.usage.total == 50 && s.lifetimeSessions?.first(where: { $0.id == "chat" })?.usage.total == 430, "children have separate totals without inherited parent usage")
        let migratedCache = root.appendingPathComponent("migration.json")
        let e = CodexUsageEvent(id: "response:cached", sessionID: "cached", recordedAt: now.addingTimeInterval(-200_000), usage: CodexTokenUsage(input: 90, cachedInput: 20, output: 10, reasoning: 5))
        struct OldCache: Encodable { var version = 1; let events: [CodexUsageEvent] }
        try JSONEncoder().encode(OldCache(events: [e])).write(to: migratedCache)
        s = await settled(CodexUsageCollector(rootDirectory: root.appendingPathComponent("missing"), historyURL: migratedCache))
        check(s.events.isEmpty && s.lifetimeSessions?.first?.usage.total == 100, "valid old numeric cache seeds lifetime before recent expiry")
        let mixedRoot = root.appendingPathComponent("mixed-source")
        try FileManager.default.createDirectory(at: mixedRoot.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        let mixedCache = root.appendingPathComponent("mixed-cache.json")
        let modernSeed = CodexUsageEvent(id: "response:identified", sessionID: "mixed", recordedAt: now.addingTimeInterval(-10), usage: CodexTokenUsage(input: 200, cachedInput: 50, output: 10, reasoning: 5))
        let oldCount = row("event_msg", ["type": "token_count", "info": ["total_token_usage": ["input_tokens": 100, "output_tokens": 10], "last_token_usage": ["input_tokens": 100, "output_tokens": 10]]], age: 200_000)
        try JSONEncoder().encode(OldCache(events: [modernSeed])).write(to: mixedCache)
        try Data((meta("mixed") + oldCount + record("identified", "mixed", 200, age: 10)).utf8).write(to: mixedRoot.appendingPathComponent("sessions/old.jsonl"))
        s = await settled(CodexUsageCollector(rootDirectory: mixedRoot, historyURL: mixedCache))
        check(s.lifetimeSessions?.first?.usage.total == 210 && s.warning?.contains("mixes cumulative") == true, "cached modern identities do not hide skipped older legacy history")
        try FileManager.default.removeItem(at: mixedRoot)
        s = await settled(CodexUsageCollector(rootDirectory: mixedRoot, historyURL: mixedCache))
        check(s.warning?.contains("mixes cumulative") == true, "mixed-history warning survives restart without source files")
        let mixedCacheOnly = root.appendingPathComponent("mixed-cache-only.json")
        let legacySeed = CodexUsageEvent(id: "legacy:mixed:old", sessionID: "mixed", recordedAt: now.addingTimeInterval(-200_000), usage: e.usage)
        try JSONEncoder().encode(OldCache(events: [legacySeed, modernSeed])).write(to: mixedCacheOnly)
        s = await settled(CodexUsageCollector(rootDirectory: mixedRoot, historyURL: mixedCacheOnly))
        check(s.lifetimeSessions?.first?.usage.total == 210 && s.warning?.contains("mixes cumulative") == true, "mixed numeric-cache migration also preserves partial-coverage provenance")
        s = await settled(CodexUsageCollector(rootDirectory: mixedRoot, historyURL: mixedCacheOnly))
        check(s.warning?.contains("mixes cumulative") == true, "cache-only mixed provenance remains durable after migrating modern records")
        let badCache = root.appendingPathComponent("bad.json")
        try Data("not sqlite".utf8).write(to: badCache.deletingPathExtension().appendingPathExtension("lifetime.sqlite"))
        s = await settled(CodexUsageCollector(rootDirectory: root, historyURL: badCache))
        check(s.lifetimeSessions == nil && !s.events.isEmpty && s.warning != nil, "broken lifetime storage is unavailable while recent collection continues")
        let compressedRoot = root.appendingPathComponent("compressed")
        try FileManager.default.createDirectory(at: compressedRoot.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("CodexUsage/Fixtures/numeric.jsonl.zst")
        try Data(contentsOf: fixture).write(to: compressedRoot.appendingPathComponent("sessions/old.jsonl.zst"))
        s = await settled(CodexUsageCollector(rootDirectory: compressedRoot), at: now.addingTimeInterval(200_000))
        check(s.events.isEmpty && (s.lifetimeSessions?.first?.usage.total ?? 0) > 0 && s.warning == nil, "compressed records older than the rolling window contribute to lifetime")
        let paired = meta("paired") + record("paired-r", "paired", 100, age: 10) + row("event_msg", ["type": "token_count", "info": ["total_token_usage": ["input_tokens": 100, "output_tokens": 10], "last_token_usage": ["input_tokens": 100, "output_tokens": 10]]], age: 10)
        let pairedRoot = root.appendingPathComponent("paired")
        try FileManager.default.createDirectory(at: pairedRoot.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        try Data(paired.utf8).write(to: pairedRoot.appendingPathComponent("sessions/paired.jsonl"))
        s = await settled(CodexUsageCollector(rootDirectory: pairedRoot))
        check(s.lifetimeSessions?.first?.usage.total == 110 && s.warning == nil, "normal modern record and cumulative notification pairs remain silent and count once")

        let store = try CodexLifetimeStore(url: nil)
        try store.begin()
        let legacy = CodexUsageEvent(id: "legacy:mixed:1", sessionID: "mixed", recordedAt: now, usage: e.usage)
        try store.record(legacy)
        try store.markModern("mixed")
        let modern = CodexUsageEvent(id: "response:mixed", sessionID: "mixed", recordedAt: now, usage: e.usage)
        try store.record(modern); try store.record(legacy); try store.record(modern)
        let totals = try store.finish()
        check(totals.count == 1 && totals[0].usage.total == 100 && store.hasMixedHistory, "modern identity replaces legacy contributions atomically and suppresses later legacy replay")
        let limited = try CodexLifetimeStore(url: nil, sessionLimit: 1)
        try limited.begin(); try limited.record(e)
        do { try limited.record(modern); fatalError("Expected explicit session limit") } catch {}
        print("PASS lifetime: session limits fail explicitly")
        let overflow = try CodexLifetimeStore(url: nil)
        try overflow.begin()
        for i in 0..<8 {
            try overflow.record(CodexUsageEvent(id: "response:huge-\(i)", sessionID: "huge", recordedAt: now, usage: CodexTokenUsage(input: Int64.max / 4, cachedInput: 0, output: Int64.max / 4, reasoning: 0)))
        }
        let clamped = try overflow.finish()
        check(clamped[0].usage.input == Int64.max / 2 && clamped[0].usage.total == Int64.max - 1, "extreme aggregates saturate without integer overflow")
    }
}
