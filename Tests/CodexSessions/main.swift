import Foundation

@main struct SessionTests {
    static func main() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func event(_ id: String, _ session: String, _ age: Double, _ input: Int64) -> CodexUsageEvent {
            CodexUsageEvent(id: id, sessionID: session, recordedAt: now.addingTimeInterval(-age), usage: CodexTokenUsage(input: input, cachedInput: 0, output: 10, reasoning: 0))
        }
        let events = [event("1", "a", 5, 100), event("2", "b", 10, 200), event("3", "a", 20, 300), event("old", "a", 86401, 999), event("future", "a", -1, 999)]
        let sessions = CodexSessionSummary.summaries(events, now: now)
        precondition(sessions.map(\.id) == ["a", "b"] && sessions[0].usage.total == 420 && sessions[1].usage.total == 210)
        precondition(CodexSessionSummary.filter(events, sessionID: "missing").isEmpty)
        precondition(CodexSessionSummary.filter(events, sessionID: "b").count == 1 && CodexSessionSummary.filter(events, sessionID: nil) == events)
        print("PASS chat grouping, expiry/future bounds, independent totals and no fallback for missing selection")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = CodexSessionIndex()
        let absent = await reader.names(root: root, now: now)
        precondition(absent.isEmpty)
        let url = root.appendingPathComponent("session_index.jsonl")
        try Data("{\"id\":\"a\",\"thread_name\":\"Physics radio\"}\n{broken}\n{\"id\":\"b\",\"thread_name\":\"模型研究\"}".utf8).write(to: url)
        var names = await reader.names(root: root, now: now.addingTimeInterval(31))
        precondition(names == ["a": "Physics radio"])
        let handle = try FileHandle(forWritingTo: url); try handle.seekToEnd(); try handle.write(contentsOf: Data("\n{\"id\":\"a\",\"thread_name\":\"Renamed chat\"}\n".utf8)); try handle.close()
        names = await reader.names(root: root, now: now.addingTimeInterval(62))
        precondition(names == ["a": "Renamed chat", "b": "模型研究"])
        print("PASS optional title index handles missing/malformed rows, split appends and renames")
        try Data((String(repeating: "x", count: 80_000) + "\n{\"id\":\"c\",\"thread_name\":\"Replacement\"}\n").utf8).write(to: url, options: .atomic)
        names = await reader.names(root: root, now: now.addingTimeInterval(93))
        precondition(names == ["c": "Replacement"])
        try FileManager.default.removeItem(at: url)
        names = await reader.names(root: root, now: now.addingTimeInterval(124))
        precondition(names.isEmpty)
        print("PASS title index replacement, oversized line and removal retain no stale names")
        let oversizedPrefix = String(repeating: " ", count: 2 * 1024 * 1024 + 100)
        try Data((oversizedPrefix + "\n{\"id\":\"after-budget\",\"thread_name\":\"Bounded continuation\"}\n").utf8).write(to: url)
        names = await reader.names(root: root, now: now.addingTimeInterval(155))
        precondition(names.isEmpty)
        names = await reader.names(root: root, now: now.addingTimeInterval(156))
        precondition(names["after-budget"] == "Bounded continuation")
        let rows = (0..<10_005).map { "{\"id\":\"id-\($0)\",\"thread_name\":\"Chat \($0)\"}\n" }.joined()
        try Data(rows.utf8).write(to: url, options: .atomic)
        names = await reader.names(root: root, now: now.addingTimeInterval(187))
        precondition(names.count == 10_000 && names["id-0"] == nil && names["id-10004"] == "Chat 10004")
        print("PASS title index resumes within its byte budget and caps retained names")
    }
}
