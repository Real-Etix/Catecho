import Foundation
import Darwin

/// Reads only rollout logs. The actor owns numeric history and bounded incremental cursors.
actor CodexUsageCollector {
    private static let pollBudget = 8 * 1024 * 1024
    private static let lineLimit = 256 * 1024
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
        var projection: CodexJSONProjection?
        var skippingLine = false
        var zstd: CodexZstd?
        var compressedInput = Data()
        var compressedFinished = false
        var sourceSize: UInt64 = 0
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

    // Discovery and refresh budgets are independent of the content byte budget.
    private static let candidateLimit = 64
    private static let inventoryLimit = 10_000
    private static let inventoryRefresh: TimeInterval = 15
    private struct InventoryFile {
        let url: URL
        var generation: Int
        var known = false
        var size: UInt64 = 0
        var inode: UInt64 = 0
        var modified: Date = .distantPast
        var unreadable = false
    }
    private struct DirectorySignature: Equatable {
        let inode: UInt64
        let modified: Date
    }
    private final class DiscoveryStatus { var failed = false }
    private final class Discovery {
        var iterators: [FileManager.DirectoryEnumerator] = []
        var index = 0
        let generation: Int
        let signatures: [String: DirectorySignature]
        let status = DiscoveryStatus()
        init(generation: Int, signatures: [String: DirectorySignature]) {
            self.generation = generation; self.signatures = signatures
        }
    }
    private var inventory: [String: InventoryFile] = [:]
    private var inventoryOrder: [String] = []
    private var metadataQueue: [String] = []
    private var metadataHead = 0
    private var sweepIndex = 0
    private var hotPaths: [String] = []
    private var discovery: Discovery?
    private var discoveryGeneration = 0
    private var hasDiscovered = false
    private var discoveryUnreadable = false
    private var lastDiscoveryAt = Date.distantPast
    private var directorySignatures: [String: DirectorySignature] = [:]

    func poll(now: Date = Date()) async -> CodexUsageSnapshot {
        loadHistory(now: now)
        let retained = events.filter { $0.value.recordedAt >= now.addingTimeInterval(-86400) && $0.value.recordedAt <= now }
        if retained.count != events.count { historyDirty = true }
        events = retained
        if events.isEmpty { historyWasLimited = false }
        if Task.isCancelled {
            saveHistory()
            return snapshot(now, issue: nil, bytes: 0, pending: !hasDiscovered || discovery != nil || hasPendingFiles, scanned: scannedFiles, total: inventory.count)
        }
        let fm = FileManager.default
        let rootAttributes: [FileAttributeKey: Any]
        do { rootAttributes = try fm.attributesOfItem(atPath: root.path) }
        catch {
            saveHistory()
            return snapshot(now, issue: isMissing(error) ? .missingFolder : .unreadable, bytes: 0, pending: false, scanned: 0, total: 0)
        }
        guard rootAttributes[.type] as? FileAttributeType == .typeDirectory else {
            saveHistory()
            return snapshot(now, issue: .missingFolder, bytes: 0, pending: false, scanned: 0, total: 0)
        }
        guard permitsReading(rootAttributes, directory: true) else {
            saveHistory()
            return snapshot(now, issue: .unreadable, bytes: 0, pending: false, scanned: 0, total: inventory.count)
        }
        var issue: CodexUsageIssue?
        // Three fixed directory probes detect removal/recreation and direct additions promptly.
        var signatures: [String: DirectorySignature] = [:]
        var folders: [URL] = []
        for name in ["sessions", "archived_sessions"] {
            let folder = root.appendingPathComponent(name)
            do {
                let attrs = try fm.attributesOfItem(atPath: folder.path)
                guard attrs[.type] as? FileAttributeType == .typeDirectory, permitsReading(attrs, directory: true) else { issue = .unreadable; continue }
                signatures[folder.path] = DirectorySignature(inode: (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0, modified: attrs[.modificationDate] as? Date ?? .distantPast)
                folders.append(folder)
            } catch { if !isMissing(error) { issue = .unreadable } }
        }
        if discovery == nil && (!hasDiscovered || signatures != directorySignatures || now.timeIntervalSince(lastDiscoveryAt) >= Self.inventoryRefresh) {
            discoveryGeneration += 1
            discoveryUnreadable = false
            let scan = Discovery(generation: discoveryGeneration, signatures: signatures)
            for folder in folders {
                let status = scan.status
                if let iterator = fm.enumerator(at: folder, includingPropertiesForKeys: [], options: [], errorHandler: { _, _ in status.failed = true; return false }) { scan.iterators.append(iterator) }
                else { scan.status.failed = true }
            }
            discovery = scan
        }
        discover(now: now, allowPruning: issue == nil)
        if discoveryUnreadable || discovery?.status.failed == true { issue = .unreadable }
        let checked = refreshMetadata()
        for path in files.keys where path.hasSuffix(".jsonl.zst") {
            if let plain = inventory[String(path.dropLast(4))], plain.known && !plain.unreadable { files.removeValue(forKey: path) }
        }
        if inventory.values.contains(where: { $0.unreadable }) { issue = .unreadable }
        var bytesRead = 0
        var decodedBytes = 0
        var selected: [String] = []
        var selectedSet: Set<String> = []
        // Continue existing decoder contexts before opening another archive (at most two).
        let decoding = files.keys.filter { files[$0]?.zstd != nil }.sorted()
        for path in hotPaths.filter({ !$0.hasSuffix(".jsonl.zst") }) + decoding + hotPaths + checked {
            if let entry = inventory[path], needsRead(path, entry), selectedSet.insert(path).inserted { selected.append(path) }
        }
        for path in inventoryOrder where selected.count < Self.candidateLimit {
            if let entry = inventory[path], needsRead(path, entry), selectedSet.insert(path).inserted { selected.append(path) }
        }
        // Content opens, metadata candidates and discovery entries all have explicit limits.
        for path in selected.prefix(Self.candidateLimit) {
            if Task.isCancelled || bytesRead >= Self.pollBudget || decodedBytes >= Self.pollBudget { break }
            guard var entry = inventory[path], entry.known, !entry.unreadable else { continue }
            var cursor = files[path] ?? Cursor()
            let compressed = path.hasSuffix(".jsonl.zst")
            if cursor.inode != entry.inode || entry.size < cursor.offset || (entry.size == cursor.offset && entry.modified != cursor.modified)
                || (compressed && (cursor.sourceSize != entry.size || cursor.modified != entry.modified)) { cursor = Cursor() }
            cursor.inode = entry.inode; cursor.modified = entry.modified
            cursor.sourceSize = entry.size
            guard cursor.offset < entry.size || (compressed && !cursor.compressedFinished) else { files[path] = cursor; continue }
            do {
                let handle = try FileHandle(forReadingFrom: entry.url)
                defer { try? handle.close() }
                try handle.seek(toOffset: cursor.offset)
                if compressed {
                    if cursor.zstd == nil && files.values.filter({ $0.zstd != nil }).count >= 2 { continue }
                    readCompressed(handle, size: entry.size, cursor: &cursor, bytes: &bytesRead, decoded: &decodedBytes, now: now)
                } else {
                    while cursor.offset < entry.size && bytesRead < Self.pollBudget && decodedBytes < Self.pollBudget && !Task.isCancelled {
                        let length = min(256 * 1024, Self.pollBudget - bytesRead, Self.pollBudget - decodedBytes, Int(min(entry.size - cursor.offset, UInt64(Int.max))))
                        guard let chunk = try handle.read(upToCount: length), !chunk.isEmpty else { break }
                        bytesRead += chunk.count; decodedBytes += chunk.count; cursor.offset += UInt64(chunk.count)
                        consume(chunk, cursor: &cursor, now: now)
                    }
                }
            } catch { issue = .unreadable; entry.unreadable = true; inventory[path] = entry }
            if cursor.tail.isEmpty { cursor.tail = Data() }
            files[path] = cursor
        }
        if files.values.reduce(0, { $0 + $1.tail.count + ($1.projection?.retainedByteEstimate ?? 0) }) > 16 * 1024 * 1024 {
            warnings.insert("Incomplete rollout lines exceeded the memory limit; history is partial.")
            for path in files.keys where !(files[path]?.tail.isEmpty ?? true) || files[path]?.projection != nil {
                files[path]?.tail = Data(); files[path]?.projection = nil; files[path]?.skippingLine = true
            }
        }
        if inventory.isEmpty && discovery == nil && hasDiscovered && issue == nil { issue = .noLogs }
        boundHistory(); saveHistory()
        return snapshot(now, issue: issue, bytes: bytesRead, pending: discovery != nil || signatures != directorySignatures || hasPendingFiles, scanned: scannedFiles, total: inventory.count)
    }
    private var hasPendingFiles: Bool {
        inventory.contains { !$0.value.known || needsRead($0.key, $0.value) }
    }
    private var scannedFiles: Int {
        inventory.filter { $0.value.known && !$0.value.unreadable && !needsRead($0.key, $0.value) }.count
    }
    private func needsRead(_ path: String, _ entry: InventoryFile) -> Bool {
        guard entry.known, !entry.unreadable else { return false }
        // When both representations exist, the live plain log has priority.
        if path.hasSuffix(".jsonl.zst"), let plain = inventory[String(path.dropLast(4))], plain.known && !plain.unreadable { return false }
        guard let cursor = files[path] else { return true }
        return cursor.inode != entry.inode || entry.size != cursor.offset || entry.modified != cursor.modified || (path.hasSuffix(".jsonl.zst") && !cursor.compressedFinished)
    }
    private func isMissing(_ error: Error) -> Bool {
        let error = error as NSError
        return (error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code)) || (error.domain == NSPOSIXErrorDomain && error.code == ENOENT)
    }
    private func permitsReading(_ attrs: [FileAttributeKey: Any], directory: Bool = false) -> Bool {
        let mode = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? 0
        return mode & 0o444 != 0 && (!directory || mode & 0o111 != 0)
    }
    private func discover(now: Date, allowPruning: Bool) {
        guard let scan = discovery else { return }
        var visited = 0
        while scan.index < scan.iterators.count && visited < Self.candidateLimit && !Task.isCancelled {
            let iterator = scan.iterators[scan.index]
            guard let url = iterator.nextObject() as? URL else { scan.index += 1; continue }
            visited += 1
            if url.lastPathComponent.hasPrefix(".") { iterator.skipDescendants(); continue }
            if url.lastPathComponent.contains(".jsonl.") && !url.lastPathComponent.hasSuffix(".jsonl.zst") {
                warnings.insert("Compressed or unsupported rollout files were skipped; history is partial."); continue
            }
            guard url.pathExtension == "jsonl" || url.lastPathComponent.hasSuffix(".jsonl.zst") else { continue }
            if var entry = inventory[url.path] { entry.generation = scan.generation; inventory[url.path] = entry }
            else if inventory.count < Self.inventoryLimit {
                inventory[url.path] = InventoryFile(url: url, generation: scan.generation)
                inventoryOrder.append(url.path); metadataQueue.append(url.path)
            } else { warnings.insert("The rollout inventory exceeded the local file limit; history is partial.") }
        }
        guard scan.index == scan.iterators.count else { return }
        if allowPruning && !scan.status.failed {
            let removed = inventory.filter { $0.value.generation != scan.generation }.map { $0.key }
            for path in removed { inventory.removeValue(forKey: path); files.removeValue(forKey: path) }
        }
        inventoryOrder.removeAll { inventory[$0] == nil }
        hotPaths.removeAll { inventory[$0] == nil }
        hasDiscovered = true; lastDiscoveryAt = now; directorySignatures = scan.signatures
        discoveryUnreadable = scan.status.failed
        if scan.status.failed { warnings.insert("Some rollout directories could not be enumerated; history is partial.") }
        discovery = nil
    }
    private func refreshMetadata() -> [String] {
        var selected: [String] = []
        var seen: Set<String> = []
        func select(_ path: String) {
            if inventory[path] != nil && seen.insert(path).inserted { selected.append(path) }
        }
        for path in hotPaths.prefix(8) { select(path) }
        var visited = 0
        while metadataHead < metadataQueue.count && selected.count < Self.candidateLimit && visited < Self.candidateLimit {
            select(metadataQueue[metadataHead]); metadataHead += 1; visited += 1
        }
        if metadataHead == metadataQueue.count { metadataQueue.removeAll(keepingCapacity: true); metadataHead = 0 }
        else if metadataHead >= 1024 { metadataQueue.removeFirst(metadataHead); metadataHead = 0 }
        visited = 0
        while selected.count < Self.candidateLimit && visited < min(inventoryOrder.count, Self.candidateLimit) {
            if sweepIndex >= inventoryOrder.count { sweepIndex = 0 }
            select(inventoryOrder[sweepIndex]); sweepIndex += 1; visited += 1
        }
        for path in selected {
            if Task.isCancelled { break }
            guard var entry = inventory[path] else { continue }
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: path)
                guard attrs[.type] as? FileAttributeType == .typeRegular else { entry.known = true; entry.unreadable = true; inventory[path] = entry; continue }
                entry.known = true
                entry.size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
                entry.inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
                entry.modified = attrs[.modificationDate] as? Date ?? .distantPast
                entry.unreadable = !permitsReading(attrs)
                inventory[path] = entry
            } catch {
                if isMissing(error) { inventory.removeValue(forKey: path); files.removeValue(forKey: path) }
                else { entry.known = true; entry.unreadable = true; inventory[path] = entry }
            }
        }
        hotPaths = Array(Set(hotPaths + selected)).filter { inventory[$0] != nil }.sorted {
            let left = inventory[$0]?.modified ?? .distantPast
            let right = inventory[$1]?.modified ?? .distantPast
            return left == right ? $0 < $1 : left > right
        }.prefix(8).map { $0 }
        return selected
    }
    private func readCompressed(_ handle: FileHandle, size: UInt64, cursor: inout Cursor, bytes: inout Int, decoded: inout Int, now: Date) {
        do {
            if cursor.zstd == nil { cursor.zstd = try CodexZstd() }
            while decoded < Self.pollBudget && !Task.isCancelled {
                if cursor.compressedInput.isEmpty && cursor.offset < size {
                    guard bytes < Self.pollBudget else { break }
                    let length = min(256 * 1024, Self.pollBudget - bytes, Int(min(size - cursor.offset, UInt64(Int.max))))
                    guard let data = try handle.read(upToCount: length), !data.isEmpty else { throw CompressedReadError.truncated }
                    cursor.compressedInput = data; cursor.offset += UInt64(data.count); bytes += data.count
                }
                let chunk = try cursor.zstd!.decode(cursor.compressedInput, outputLimit: min(256 * 1024, Self.pollBudget - decoded))
                cursor.compressedInput = Data(cursor.compressedInput.dropFirst(chunk.consumed))
                decoded += chunk.output.count
                consume(chunk.output, cursor: &cursor, now: now)
                if chunk.frameComplete && cursor.offset == size && cursor.compressedInput.isEmpty {
                    cursor.compressedFinished = true; cursor.zstd = nil
                    // A complete archive may omit the final JSONL newline.
                    finishLine(cursor: &cursor, now: now)
                    break
                }
                if chunk.consumed == 0 && chunk.output.isEmpty {
                    if cursor.offset == size { throw CompressedReadError.truncated }
                    if !cursor.compressedInput.isEmpty { throw CompressedReadError.invalid }
                }
            }
        } catch {
            warnings.insert("Some compressed rollout history could not be decoded (invalid, incomplete, or beyond the 8 MiB window limit); history is partial.")
            cursor.zstd = nil; cursor.compressedInput = Data(); cursor.compressedFinished = true; cursor.offset = size
            cursor.tail = Data(); cursor.projection = nil; cursor.skippingLine = false
        }
    }
    private enum CompressedReadError: Error { case truncated, invalid }
    private func consume(_ chunk: Data, cursor: inout Cursor, now: Date) {
        chunk.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var start = 0
            while start < chunk.count {
                let newline = memchr(base.advanced(by: start), 10, chunk.count - start)
                let end = newline.map { base.distance(to: UnsafeRawPointer($0)) } ?? chunk.count
                if !cursor.skippingLine {
                    if cursor.projection == nil && cursor.tail.count + end - start > Self.lineLimit {
                        cursor.projection = CodexJSONProjection()
                        cursor.projection?.consume(cursor.tail)
                        cursor.tail = Data()
                    }
                    if let projection = cursor.projection { projection.consume(Data(chunk[start..<end])) }
                    else { cursor.tail.append(chunk[start..<end]) }
                }
                if end < chunk.count {
                    finishLine(cursor: &cursor, now: now)
                    start = end + 1
                } else { break }
            }
        }
    }
    private func finishLine(cursor: inout Cursor, now: Date) {
        if !cursor.skippingLine {
            if let projection = cursor.projection {
                if let line = projection.finish() { parse(line, cursor: &cursor, now: now) }
                else { warnings.insert("Some oversized rollout records could not be decoded within the structural limits; history is partial.") }
            } else if !cursor.tail.isEmpty { parse(cursor.tail, cursor: &cursor, now: now) }
        }
        cursor.tail = Data(); cursor.projection = nil; cursor.skippingLine = false
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
                    let input = current.input - previous.input
                    let output = current.output - previous.output
                    let cached = current.cachedInput - previous.cachedInput
                    let reasoning = current.reasoning - previous.reasoning
                    if cached > input || reasoning > output {
                        warnings.insert("Cumulative subset counters changed inconsistently; cached input and reasoning deltas were limited to raw usage.")
                    }
                    delta = CodexTokenUsage(input: input, cachedInput: min(input, cached), output: output, reasoning: min(output, reasoning))
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
