import Foundation

@main struct WindowTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func event(_ age: Double, _ input: Int64) -> CodexUsageEvent {
            CodexUsageEvent(id: String(age), sessionID: "fixture", recordedAt: now.addingTimeInterval(-age), usage: CodexTokenUsage(input: input, cachedInput: input / 2, output: input / 10, reasoning: input / 20))
        }
        let events = [event(0, 100), event(1, 200), event(59.99, 300), event(60, 400), event(3599, 500), event(3600, 600), event(-1, 700)]
        let total = CodexUsageWindow.second.total(events, now: now)
        precondition(total.total == 660 && total.cachedInput == 300 && total.reasoning == 30, "Exclude exact lower boundary and future events; subsets are not added")
        precondition(CodexUsageWindow.minute.total(events, now: now) == total)
        precondition(CodexUsageWindow.hour.total(events, now: now).total == 1650)
        print("PASS headline windows use (now - interval, now] without counting subsets twice")
        let seconds = CodexUsageWindow.second.bins(events, now: now)
        precondition(seconds.count == 60 && seconds[59] == 110 && seconds[58] == 220 && seconds[0] == 330 && seconds.reduce(0, +) == 660)
        let minutes = CodexUsageWindow.minute.bins(events, now: now)
        precondition(minutes.count == 60 && minutes[59] == 660 && minutes[58] == 440 && minutes[0] == 550)
        let hours = CodexUsageWindow.hour.bins(events, now: now)
        precondition(hours.count == 24 && hours[23] == 1650 && hours[22] == 660)
        print("PASS rolling chart bins preserve actual burst timestamps and zero activity")
        precondition(CodexUsageWindow.second.total(events, now: now.addingTimeInterval(61)).total == 0)
        print("PASS idle headline decays to zero without new records")
    }
}
