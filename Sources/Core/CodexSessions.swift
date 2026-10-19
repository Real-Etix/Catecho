import Foundation

struct CodexSessionSummary: Identifiable, Sendable {
    let id: String
    let lastRecordedAt: Date
    let usage: CodexTokenUsage

    static func filter(_ events: [CodexUsageEvent], sessionID: String?) -> [CodexUsageEvent] {
        guard let sessionID else { return events }
        return events.filter { $0.sessionID == sessionID }
    }
    static func summaries(_ events: [CodexUsageEvent], now: Date) -> [CodexSessionSummary] {
        var sessions: [String: CodexSessionSummary] = [:]
        for event in events where event.recordedAt >= now.addingTimeInterval(-86400) && event.recordedAt <= now {
            let old = sessions[event.sessionID]
            let add = CodexUsageWindow.add
            let usage = CodexTokenUsage(input: add(old?.usage.input ?? 0, event.usage.input), cachedInput: add(old?.usage.cachedInput ?? 0, event.usage.cachedInput), output: add(old?.usage.output ?? 0, event.usage.output), reasoning: add(old?.usage.reasoning ?? 0, event.usage.reasoning))
            sessions[event.sessionID] = CodexSessionSummary(id: event.sessionID, lastRecordedAt: max(old?.lastRecordedAt ?? .distantPast, event.recordedAt), usage: usage)
        }
        return sessions.values.sorted { $0.lastRecordedAt == $1.lastRecordedAt ? $0.id < $1.id : $0.lastRecordedAt > $1.lastRecordedAt }
    }
}
