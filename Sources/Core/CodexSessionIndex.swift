import Foundation
import Darwin

/// Optional display metadata only. Names stay in memory; no message content is read.
actor CodexSessionIndex {
    private var rootPath = ""
    private var titles: [String: String] = [:]
    private var order: [String] = []
    private var orderHead = 0
    private var offset: UInt64 = 0
    private var inode: UInt64 = 0
    private var modified = Date.distantPast
    private var lastCheck = Date.distantPast
    private var pending = false
    private var tail = Data()
    private var skipping = false
    private struct Row: Decodable { let id: String; let thread_name: String }

    func names(root: URL, now: Date = Date()) -> [String: String] {
        if rootPath != root.path { reset(); rootPath = root.path; lastCheck = .distantPast }
        guard pending || now.timeIntervalSince(lastCheck) >= 30 else { return titles }
        lastCheck = now
        let url = root.appendingPathComponent("session_index.jsonl")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else { reset(); return [:] }
            let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
            let nextInode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
            let nextModified = attributes[.modificationDate] as? Date ?? .distantPast
            if nextInode != inode || size < offset || (size == offset && nextModified != modified) { reset() }
            inode = nextInode; modified = nextModified
            let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
            try handle.seek(toOffset: offset)
            var budget = 2 * 1024 * 1024
            while offset < size && budget > 0 && !Task.isCancelled {
                guard let chunk = try handle.read(upToCount: min(64 * 1024, budget, Int(min(size - offset, UInt64(Int.max))))), !chunk.isEmpty else { break }
                offset += UInt64(chunk.count); budget -= chunk.count
                consume(chunk)
            }
            pending = offset < size
        } catch { reset() }
        return titles
    }
    private func reset() {
        titles = [:]; order = []; orderHead = 0; offset = 0; inode = 0; modified = .distantPast
        pending = false; tail = Data(); skipping = false
    }
    private func consume(_ data: Data) {
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var start = 0
            while start < raw.count {
                let end = memchr(base.advanced(by: start), 10, raw.count - start).map { base.distance(to: UnsafeRawPointer($0)) } ?? raw.count
                if !skipping {
                    if tail.count + end - start <= 64 * 1024 { tail.append(data[start..<end]) }
                    else { tail = Data(); skipping = true }
                }
                if end == raw.count { break }
                if !skipping, let row = try? JSONDecoder().decode(Row.self, from: tail), !row.id.isEmpty, row.id.utf8.count <= 256 {
                    let clean = row.thread_name.components(separatedBy: .controlCharacters).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        if titles[row.id] == nil { order.append(row.id) }
                        titles[row.id] = String(clean.prefix(256))
                        while titles.count > 10_000 {
                            titles.removeValue(forKey: order[orderHead]); orderHead += 1
                        }
                        if orderHead > 1024 { order.removeFirst(orderHead); orderHead = 0 }
                    }
                }
                tail = Data(); skipping = false; start = end + 1
            }
        }
    }
}
