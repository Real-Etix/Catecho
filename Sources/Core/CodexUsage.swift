import Foundation

struct CodexTokenUsage: Codable, Sendable, Equatable {
    let input: Int64
    let cachedInput: Int64
    let output: Int64
    let reasoning: Int64
    var total: Int64 { input + output }
}
struct CodexUsageEvent: Codable, Sendable, Equatable {
    let id: String
    let sessionID: String
    let recordedAt: Date
    let usage: CodexTokenUsage
}
enum CodexUsageIssue: String, Codable, Sendable { case missingFolder, noLogs, unreadable }
struct CodexUsageSnapshot: Sendable {
    let events: [CodexUsageEvent]
    let checkedAt: Date
    let lastRecordedAt: Date?
    let isIndexing: Bool
    let filesScanned: Int
    let filesTotal: Int
    let issue: CodexUsageIssue?
    let warning: String?
    let bytesRead: Int
}
