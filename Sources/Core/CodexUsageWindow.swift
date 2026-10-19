import Foundation

enum CodexUsageWindow: String, CaseIterable {
    case lifetime, second, minute, hour
    var interval: TimeInterval { self == .lifetime ? .infinity : self == .hour ? 3600 : 60 }
    var binWidth: TimeInterval { self == .second ? 1 : self == .minute ? 60 : 3600 }
    var binCount: Int { self == .hour || self == .lifetime ? 24 : 60 }
    var label: String { self == .lifetime ? "TOTAL" : self == .second ? "SEC" : self == .minute ? "MIN" : "HR" }
    var detail: String { self == .lifetime ? "Lifetime · available local records" : self == .second ? "Average over the last 60 seconds" : self == .minute ? "Recorded in the last 60 seconds" : "Recorded in the last hour" }
    func total(_ events: [CodexUsageEvent], now: Date) -> CodexTokenUsage {
        let matching = events.filter { (self == .lifetime || $0.recordedAt > now.addingTimeInterval(-interval)) && $0.recordedAt <= now }
        return CodexTokenUsage(input: matching.reduce(0) { Self.add($0, $1.usage.input) }, cachedInput: matching.reduce(0) { Self.add($0, $1.usage.cachedInput) }, output: matching.reduce(0) { Self.add($0, $1.usage.output) }, reasoning: matching.reduce(0) { Self.add($0, $1.usage.reasoning) })
    }
    // Clamp malformed/extreme aggregate values instead of trapping on an integer overflow.
    static func add(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max / 2 : min(sum, Int64.max / 2)
    }
    func bins(_ events: [CodexUsageEvent], now: Date) -> [Int64] {
        var values = Array(repeating: Int64(0), count: binCount)
        for event in events {
            let age = now.timeIntervalSince(event.recordedAt)
            guard age >= 0, age < Double(binCount) * binWidth else { continue }
            let index = binCount - 1 - Int(age / binWidth)
            values[index] = Self.add(values[index], event.usage.total)
        }
        return values
    }
}
