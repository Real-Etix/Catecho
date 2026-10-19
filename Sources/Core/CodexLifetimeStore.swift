import Foundation
import SQLite3

/// Numeric-only, durable identity ledger. Access is confined to the collector actor.
final class CodexLifetimeStore {
    private var db: OpaquePointer?
    private var statements: [String: OpaquePointer] = [:]
    private var sessionIDs: Set<String> = []
    private(set) var modernSessions: Set<String> = []
    private(set) var hasMixedHistory = false
    private let sessionLimit: Int
    private var transaction = false
    private var changed = true
    private var summaries: [CodexSessionSummary] = []
    private static let cap = Int64.max / 2
    enum Failure: Error { case storage, limit }
    private enum Value { case text(String), integer(Int64), real(Double) }

    init(url: URL?, sessionLimit: Int = 10_000) throws {
        self.sessionLimit = sessionLimit
        if let url { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true) }
        guard sqlite3_open_v2(url?.path ?? ":memory:", &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(db); db = nil; throw Failure.storage
        }
        do {
            sqlite3_busy_timeout(db, 500)
            try execute("PRAGMA foreign_keys=ON")
            try execute("PRAGMA journal_mode=DELETE")
            try execute("PRAGMA synchronous=FULL")
            try execute("PRAGMA cache_size=-2048")
            try execute("PRAGMA max_page_count=65536")
            let version = try statement("PRAGMA user_version")
            guard sqlite3_step(version) == SQLITE_ROW, sqlite3_column_int(version, 0) <= 1 else { throw Failure.storage }
            sqlite3_reset(version)
            try execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY, modern INTEGER NOT NULL DEFAULT 0, mixed INTEGER NOT NULL DEFAULT 0,
                    first REAL, last REAL, input INTEGER NOT NULL DEFAULT 0, cached INTEGER NOT NULL DEFAULT 0,
                    output INTEGER NOT NULL DEFAULT 0, reasoning INTEGER NOT NULL DEFAULT 0)
                """)
            try execute("""
                CREATE TABLE IF NOT EXISTS usage (
                    id TEXT PRIMARY KEY, session TEXT NOT NULL REFERENCES sessions(id), at REAL NOT NULL,
                    input INTEGER NOT NULL, cached INTEGER NOT NULL, output INTEGER NOT NULL, reasoning INTEGER NOT NULL)
                """)
            try execute("CREATE INDEX IF NOT EXISTS usage_session ON usage(session)")
            try execute("""
                CREATE TRIGGER IF NOT EXISTS accumulate AFTER INSERT ON usage BEGIN
                    UPDATE sessions SET first=MIN(COALESCE(first, NEW.at), NEW.at), last=MAX(COALESCE(last, NEW.at), NEW.at),
                        input=MIN(\(Self.cap), input+NEW.input), cached=MIN(\(Self.cap), cached+NEW.cached),
                        output=MIN(\(Self.cap), output+NEW.output), reasoning=MIN(\(Self.cap), reasoning+NEW.reasoning)
                    WHERE id=NEW.session;
                END
                """)
            try execute("PRAGMA user_version=1")
            let rows = try statement("SELECT id, modern, mixed FROM sessions")
            var result = sqlite3_step(rows)
            while result == SQLITE_ROW {
                let id = string(rows, 0)
                sessionIDs.insert(id)
                guard sessionIDs.count <= sessionLimit else { throw Failure.limit }
                if sqlite3_column_int(rows, 1) != 0 { modernSessions.insert(id) }
                if sqlite3_column_int(rows, 2) != 0 { hasMixedHistory = true }
                result = sqlite3_step(rows)
            }
            sqlite3_reset(rows)
            guard result == SQLITE_DONE else { throw Failure.storage }
        } catch { close(); throw error }
    }
    deinit { close() }
    private func close() {
        for s in statements.values { sqlite3_finalize(s) }
        statements.removeAll()
        if transaction { sqlite3_exec(db, "ROLLBACK", nil, nil, nil) }
        sqlite3_close(db); db = nil
    }
    func begin() throws {
        guard !transaction else { return }
        try execute("BEGIN IMMEDIATE"); transaction = true
    }
    private func ensureSession(_ id: String) throws {
        guard !sessionIDs.contains(id) else { return }
        guard sessionIDs.count < sessionLimit else { throw Failure.limit }
        try execute("INSERT OR IGNORE INTO sessions(id) VALUES (?)", [.text(id)])
        sessionIDs.insert(id)
    }
    func markModern(_ session: String) throws {
        guard !modernSessions.contains(session) else { return }
        try ensureSession(session)
        // A session has only one accounting schema. Removing its legacy entries
        // and replacing its aggregate is atomic with the first identified record.
        try execute("DELETE FROM usage WHERE session=?", [.text(session)])
        let mixed = sqlite3_changes(db) > 0
        try execute("UPDATE sessions SET modern=1, mixed=MAX(mixed, ?), first=NULL, last=NULL, input=0, cached=0, output=0, reasoning=0 WHERE id=?", [.integer(mixed ? 1 : 0), .text(session)])
        modernSessions.insert(session); hasMixedHistory = hasMixedHistory || mixed; changed = true
    }
    func noteMixedHistory(_ session: String) throws {
        try ensureSession(session)
        try execute("UPDATE sessions SET mixed=1 WHERE id=?", [.text(session)])
        hasMixedHistory = true
    }
    func record(_ event: CodexUsageEvent) throws {
        if event.id.hasPrefix("legacy:"), modernSessions.contains(event.sessionID) { return }
        if event.id.hasPrefix("response:") { try markModern(event.sessionID) }
        try ensureSession(event.sessionID)
        try execute("INSERT OR IGNORE INTO usage(id, session, at, input, cached, output, reasoning) VALUES (?, ?, ?, ?, ?, ?, ?)", [
            .text(event.id), .text(event.sessionID), .real(event.recordedAt.timeIntervalSince1970),
            .integer(event.usage.input), .integer(event.usage.cachedInput), .integer(event.usage.output), .integer(event.usage.reasoning)
        ])
        changed = changed || sqlite3_changes(db) > 0
    }
    func finish() throws -> [CodexSessionSummary] {
        if transaction { try execute("COMMIT"); transaction = false }
        guard changed else { return summaries }
        var values: [CodexSessionSummary] = []
        let rows = try statement("SELECT id, last, input, cached, output, reasoning FROM sessions WHERE last IS NOT NULL ORDER BY last DESC, id")
        defer { sqlite3_reset(rows) }
        var result = sqlite3_step(rows)
        while result == SQLITE_ROW {
            values.append(CodexSessionSummary(id: string(rows, 0), lastRecordedAt: Date(timeIntervalSince1970: sqlite3_column_double(rows, 1)), usage: CodexTokenUsage(input: sqlite3_column_int64(rows, 2), cachedInput: sqlite3_column_int64(rows, 3), output: sqlite3_column_int64(rows, 4), reasoning: sqlite3_column_int64(rows, 5))))
            result = sqlite3_step(rows)
        }
        guard result == SQLITE_DONE else { throw Failure.storage }
        summaries = values; changed = false
        return values
    }
    private func statement(_ sql: String) throws -> OpaquePointer {
        if let s = statements[sql] { sqlite3_reset(s); sqlite3_clear_bindings(s); return s }
        var s: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &s, nil) == SQLITE_OK, let s else { throw Failure.storage }
        statements[sql] = s; return s
    }
    private func execute(_ sql: String, _ values: [Value] = []) throws {
        let s = try statement(sql)
        defer { sqlite3_reset(s) }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .text(let text): result = text.withCString { sqlite3_bind_text(s, index, $0, Int32(text.utf8.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            case .integer(let number): result = sqlite3_bind_int64(s, index, number)
            case .real(let number): result = sqlite3_bind_double(s, index, number)
            }
            guard result == SQLITE_OK else { throw Failure.storage }
        }
        var result = sqlite3_step(s)
        while result == SQLITE_ROW { result = sqlite3_step(s) }
        guard result == SQLITE_DONE else { throw Failure.storage }
    }
    private func string(_ s: OpaquePointer, _ column: Int32) -> String {
        guard let bytes = sqlite3_column_text(s, column) else { return "" }
        return String(decoding: UnsafeBufferPointer(start: bytes, count: Int(sqlite3_column_bytes(s, column))), as: UTF8.self)
    }
}
