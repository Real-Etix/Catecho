import Foundation
import Darwin

/// Reads only rollout logs. The actor owns numeric history and bounded incremental cursors.
actor CodexUsageCollector {
    private static let pollBudget = 8 * 1024 * 1024
    private static let lineLimit = 8 * 1024 * 1024
    private static let historyLimit = 20_000
    private let root: URL
    private let historyURL: URL?
    private var files: [String: Cursor] = [:]
    private var events: [String: CodexUsageEvent] = [:]
    private var modernSessions: Set<String> = []
    private var legacySessions: Set<String> = []
    private var warnings: Set<String> = []
    private var didLoadHistory = false
    private var historyDirty = false
    private var historyWasLimited = false
    private let decoder = JSONDecoder()
    private let fractionalDate = ISO8601DateFormatter()
    private let wholeDate = ISO8601DateFormatter()

    private struct Cursor {
        var offset: UInt64 = 0
        var inode: UInt64 = 0
        var modified: Date = .distantPast
        var tail = Data()
        var skippingLine = false
        var session = ""
        var born: Date?
        var isChild = false
        var previous: CodexTokenUsage?
        var modern = false
    }
    private struct Counts: Decodable {
        var input_tokens: Int64?
        var cached_input_tokens: Int64?
        var output_tokens: Int64?
        var reasoning_output_tokens: Int64?
        var value: CodexTokenUsage? {
            guard let input = input_tokens, let output = output_tokens,
                  input >= 0, output >= 0, input <= Int64.max / 4, output <= Int64.max / 4 else { return nil }
            return CodexTokenUsage(input: input, cachedInput: min(input, max(0, cached_input_tokens ?? 0)), output: output, reasoning: min(output, max(0, reasoning_output_tokens ?? 0)))
        }
    }
    private struct Info: Decodable { var total_token_usage: Counts?; var last_token_usage: Counts? }
    private struct UsageRecord: Decodable {
        var response_id: String?; var thread_id: String?; var session_id: String?; var usage: Counts?
    }
    private struct Payload: Decodable {
        var id: String?; var timestamp: String?; var parent_thread_id: String?
        var source: Source?
        var type: String?; var info: Info?
        var response_id: String?; var thread_id: String?; var session_id: String?; var usage: Counts?
        var compaction_response_id: String?; var latest_token_usage_record: UsageRecord?
    }
    private struct Source: Decodable {
        var isChild: Bool
        init(from decoder: Decoder) throws {
            if let container = try? decoder.container(keyedBy: Key.self) { isChild = container.contains(.subagent) }
            else { isChild = false }
        }
        enum Key: String, CodingKey { case subagent }
    }
    private struct Row: Decodable { var type: String; var timestamp: String?; var payload: Payload? }
    private struct History: Codable { var version: Int; var events: [CodexUsageEvent]; var wasLimited: Bool? = nil }

    init(rootDirectory: URL, historyURL: URL? = nil) {
        root = rootDirectory
        self.historyURL = historyURL
        fractionalDate.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func poll(now: Date = Date()) async -> CodexUsageSnapshot {
        loadHistory(now: now)
        let retained = events.filter { $0.value.recordedAt >= now.addingTimeInterval(-86400) && $0.value.recordedAt <= now }
        if retained.count != events.count { historyDirty = true }
        events = retained
        if events.isEmpty { historyWasLimited = false }
        var bytesRead = 0
        var issue: CodexUsageIssue?
        let fm = FileManager.default
        var directory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &directory), directory.boolValue else {
            return snapshot(now, issue: .missingFolder, bytes: 0, pending: false, scanned: 0, total: 0)
        }
        var paths: [(URL, UInt64, UInt64, Date)] = []
        for name in ["sessions", "archived_sessions"] {
            let folder = root.appendingPathComponent(name)
            guard fm.fileExists(atPath: folder.path) else { continue }
            guard readable(folder) else { issue = .unreadable; continue }
            var enumerationFailed = false
            guard let iterator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles], errorHandler: { _, _ in enumerationFailed = true; return false }) else { issue = .unreadable; continue }
            for case let url as URL in iterator {
                if url.lastPathComponent.contains(".jsonl.") {
                    warnings.insert("Compressed or unsupported rollout files were skipped; history is partial.")
                    continue
                }
                guard url.pathExtension == "jsonl" else { continue }
                guard let attrs = try? fm.attributesOfItem(atPath: url.path), attrs[.type] as? FileAttributeType == .typeRegular else { issue = .unreadable; continue }
                paths.append((url, (attrs[.size] as? NSNumber)?.uint64Value ?? 0, (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0, attrs[.modificationDate] as? Date ?? .distantPast))
            }
            if enumerationFailed { issue = .unreadable }
        }
        paths.sort { $0.0.path < $1.0.path }
        let currentPaths = Set(paths.map { $0.0.path })
        files = files.filter { currentPaths.contains($0.key) }
        if paths.isEmpty && issue == nil { issue = .noLogs }
        // Complete the current file before starting another, bounding aggregate line buffering.
        let ordered = paths.sorted {
            let left = files[$0.0.path].map { !$0.tail.isEmpty } ?? false
            let right = files[$1.0.path].map { !$0.tail.isEmpty } ?? false
            return left != right ? left : $0.0.path < $1.0.path
        }
        for (url, size, inode, modified) in ordered {
            if Task.isCancelled { break }
            var cursor = files[url.path] ?? Cursor()
            if cursor.inode != inode || size < cursor.offset || (size == cursor.offset && modified != cursor.modified) {
                cursor = Cursor()
            }
            cursor.inode = inode; cursor.modified = modified
            guard cursor.offset < size else { files[url.path] = cursor; continue }
            guard bytesRead < Self.pollBudget else { files[url.path] = cursor; continue }
            guard readable(url), let handle = try? FileHandle(forReadingFrom: url) else {
                issue = .unreadable; files[url.path] = cursor; continue
            }
            defer { try? handle.close() }
            do {
                try handle.seek(toOffset: cursor.offset)
                while cursor.offset < size && bytesRead < Self.pollBudget && !Task.isCancelled {
                    let length = min(256 * 1024, Self.pollBudget - bytesRead, Int(min(size - cursor.offset, UInt64(Int.max))))
                    guard let chunk = try handle.read(upToCount: length), !chunk.isEmpty else { break }
                    bytesRead += chunk.count; cursor.offset += UInt64(chunk.count)
                    consume(chunk, cursor: &cursor, now: now)
                }
            } catch { issue = .unreadable }
            if cursor.tail.isEmpty { cursor.tail = Data() }
            files[url.path] = cursor
        }
        if files.values.reduce(0, { $0 + $1.tail.count }) > 16 * 1024 * 1024 {
            warnings.insert("Incomplete rollout lines exceeded the memory limit; history is partial.")
            for path in files.keys where !(files[path]?.tail.isEmpty ?? true) {
                files[path]?.tail.removeAll(keepingCapacity: false); files[path]?.skippingLine = true
            }
        }
        let scanned = paths.filter { files[$0.0.path]?.offset == $0.1 }.count
        let pending = paths.contains { item in
            guard readable(item.0) else { return false }
            return (files[item.0.path]?.offset ?? 0) < item.1
        }
        boundHistory()
        saveHistory()
        return snapshot(now, issue: issue, bytes: bytesRead, pending: pending, scanned: scanned, total: paths.count)
    }

    private func readable(_ url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), let mode = attrs[.posixPermissions] as? NSNumber else { return false }
        return mode.intValue & 0o444 != 0 && FileManager.default.isReadableFile(atPath: url.path)
    }
    private func consume(_ chunk: Data, cursor: inout Cursor, now: Date) {
        chunk.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var start = 0
            while start < chunk.count {
                let newline = memchr(base.advanced(by: start), 10, chunk.count - start)
                let end = newline.map { base.distance(to: UnsafeRawPointer($0)) } ?? chunk.count
                if !cursor.skippingLine {
                    if cursor.tail.count + end - start <= Self.lineLimit { cursor.tail.append(chunk[start..<end]) }
                    else {
                        cursor.tail.removeAll(keepingCapacity: false); cursor.skippingLine = true
                        warnings.insert("An oversized rollout line was skipped; history is partial.")
                    }
                }
                if end < chunk.count {
                    if !cursor.skippingLine && !cursor.tail.isEmpty { parse(cursor.tail, cursor: &cursor, now: now) }
                    cursor.tail.removeAll(keepingCapacity: cursor.tail.count <= 256 * 1024); cursor.skippingLine = false
                    start = end + 1
                } else { break }
            }
        }
    }
    private func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        return fractionalDate.date(from: text) ?? wholeDate.date(from: text)
    }
    private func parse(_ line: Data, cursor: inout Cursor, now: Date) {
        guard let row = try? decoder.decode(Row.self, from: line) else {
            warnings.insert("Some rollout records could not be decoded; history is partial.")
            return
        }
        guard let p = row.payload else { return }
        if row.type == "session_meta" {
            cursor.session = p.id ?? ""
            if cursor.session.utf8.count > 256 {
                cursor.session = ""
                warnings.insert("An oversized session identifier was skipped; history is partial.")
            }
            cursor.born = date(p.timestamp) ?? date(row.timestamp)
            cursor.isChild = p.parent_thread_id != nil || p.source?.isChild == true
            return
        }
        guard row.type == "token_usage_record" || row.type == "compacted" || (row.type == "event_msg" && p.type == "token_count") else { return }
        guard let recordedAt = date(row.timestamp) else { return }
        if cursor.isChild, let born = cursor.born, recordedAt < born { return }
        if row.type == "token_usage_record" {
            addModern(id: p.response_id, session: p.thread_id ?? p.session_id, usage: p.usage?.value, at: recordedAt, cursor: &cursor, now: now)
        } else if row.type == "compacted", let r = p.latest_token_usage_record {
            addModern(id: r.response_id ?? p.compaction_response_id, session: r.thread_id ?? r.session_id, usage: r.usage?.value, at: recordedAt, cursor: &cursor, now: now)
        } else if row.type == "event_msg", p.type == "token_count", let current = p.info?.total_token_usage?.value {
            let previous = cursor.previous
            cursor.previous = current
            guard !cursor.session.isEmpty else { warnings.insert("Usage without session identity was skipped; history is partial."); return }
            guard !cursor.modern && !modernSessions.contains(cursor.session) else { return }
            var delta: CodexTokenUsage?
            if let previous {
                if previous == current { return }
                if current.input >= previous.input && current.output >= previous.output && current.cachedInput >= previous.cachedInput && current.reasoning >= previous.reasoning {
                    delta = CodexTokenUsage(input: current.input - previous.input, cachedInput: current.cachedInput - previous.cachedInput, output: current.output - previous.output, reasoning: current.reasoning - previous.reasoning)
                } else { delta = p.info?.last_token_usage?.value }
            } else { delta = p.info?.last_token_usage?.value }
            guard let delta else { warnings.insert("A cumulative counter had no reliable baseline; history is partial."); return }
            let id = "legacy:\(cursor.session):\(recordedAt.timeIntervalSince1970):\(current.input):\(current.cachedInput):\(current.output):\(current.reasoning)"
            legacySessions.insert(cursor.session)
            insert(CodexUsageEvent(id: id, sessionID: cursor.session, recordedAt: recordedAt, usage: delta), now: now)
        }
    }
    private func addModern(id: String?, session: String?, usage: CodexTokenUsage?, at: Date, cursor: inout Cursor, now: Date) {
        guard let id, !id.isEmpty, let usage else { warnings.insert("A response usage record was incomplete; history is partial."); return }
        let session = session ?? cursor.session
        guard id.utf8.count <= 256, session.utf8.count <= 256, !session.isEmpty else {
            warnings.insert("An oversized usage identifier was skipped; history is partial."); return
        }
        // Copied parent usage retains its original thread identity.
        if !cursor.session.isEmpty && session != cursor.session { return }
        cursor.modern = true
        modernSessions.insert(session)
        // The modern record normally precedes token_count; also reconcile an earlier snapshot.
        if legacySessions.remove(session) != nil {
            let legacy = events.values.filter { $0.sessionID == session && $0.id.hasPrefix("legacy:") }
            for item in legacy {
                events.removeValue(forKey: item.id)
                historyDirty = true
                if abs(item.recordedAt.timeIntervalSince(at)) > 2 || item.usage != usage {
                    warnings.insert("A session mixes cumulative and response records; only identified response usage is shown for that session.")
                }
            }
        }
        insert(CodexUsageEvent(id: "response:" + id, sessionID: session, recordedAt: at, usage: usage), now: now)
    }
    private func insert(_ event: CodexUsageEvent, now: Date) {
        guard event.recordedAt >= now.addingTimeInterval(-86400), event.recordedAt <= now, event.usage.total > 0 else { return }
        if events[event.id] == nil { events[event.id] = event; historyDirty = true }
    }
    private func boundHistory() {
        guard events.count > Self.historyLimit else { return }
        historyDirty = true
        historyWasLimited = true
        events = Dictionary(uniqueKeysWithValues: events.values.sorted { $0.recordedAt > $1.recordedAt }.prefix(Self.historyLimit).map { ($0.id, $0) })
        warnings.insert("Recorded usage exceeded the local history limit; history is partial.")
    }
    private func loadHistory(now: Date) {
        guard !didLoadHistory else { return }; didLoadHistory = true
        guard let url = historyURL, FileManager.default.fileExists(atPath: url.path) else { return }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), (attrs[.size] as? NSNumber)?.intValue ?? Int.max <= 8 * 1024 * 1024,
              let data = try? Data(contentsOf: url), let history = try? decoder.decode(History.self, from: data), history.version == 1 else {
            warnings.insert("The numeric usage cache could not be restored; history is being rebuilt."); return
        }
        historyWasLimited = history.wasLimited == true || history.events.count > Self.historyLimit
        if historyWasLimited && history.events.contains(where: { $0.recordedAt >= now.addingTimeInterval(-86400) && $0.recordedAt <= now }) {
            warnings.insert("The restored numeric history was limited; history is partial.")
        }
        for event in history.events.prefix(Self.historyLimit) {
            guard event.id.utf8.count <= 1024, event.sessionID.utf8.count <= 256,
                  event.usage.input >= 0, event.usage.output >= 0,
                  event.usage.input <= Int64.max / 4, event.usage.output <= Int64.max / 4,
                  event.usage.cachedInput >= 0, event.usage.cachedInput <= event.usage.input,
                  event.usage.reasoning >= 0, event.usage.reasoning <= event.usage.output else {
                warnings.insert("Invalid numeric cache records were skipped; history is partial."); continue
            }
            events[event.id] = event
            if event.id.hasPrefix("response:") { modernSessions.insert(event.sessionID) }
            if event.id.hasPrefix("legacy:") { legacySessions.insert(event.sessionID) }
        }
    }
    private func saveHistory() {
        guard historyDirty, let url = historyURL else { return }
        do {
            var ordered = events.values.sorted { $0.recordedAt < $1.recordedAt }
            var data = try JSONEncoder().encode(History(version: 1, events: ordered, wasLimited: historyWasLimited))
            while data.count > 8 * 1024 * 1024 && !ordered.isEmpty {
                ordered = Array(ordered.suffix(ordered.count * 3 / 4))
                historyWasLimited = true
                data = try JSONEncoder().encode(History(version: 1, events: ordered, wasLimited: historyWasLimited))
                warnings.insert("Recorded usage exceeded the local cache size limit; history is partial.")
                events = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) })
            }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            historyDirty = false
        } catch { warnings.insert("The numeric usage cache could not be saved.") }
    }
    private func snapshot(_ now: Date, issue: CodexUsageIssue?, bytes: Int, pending: Bool, scanned: Int, total: Int) -> CodexUsageSnapshot {
        let ordered = events.values.sorted { $0.recordedAt == $1.recordedAt ? $0.id < $1.id : $0.recordedAt < $1.recordedAt }
        return CodexUsageSnapshot(events: ordered, checkedAt: now, lastRecordedAt: ordered.last?.recordedAt, isIndexing: pending, filesScanned: scanned, filesTotal: total, issue: issue, warning: warnings.isEmpty ? nil : warnings.sorted().joined(separator: " "), bytesRead: bytes)
    }
}
