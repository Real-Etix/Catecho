import Foundation
import SwiftUI

@main struct MonitorTests {
    @MainActor static func wait(_ condition: () -> Bool) async {
        for _ in 0..<1000 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        fatalError("Monitor did not reach the expected state")
    }
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "Catecho.MonitorTest." + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        defer { try? FileManager.default.removeItem(at: directory); preferences.removePersistentDomain(forName: suite) }
        let root = directory.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        preferences.set(root.path, forKey: "codexRootPath")
        let monitor = CodexMonitorModel(preferences: preferences, historyDirectory: directory.appendingPathComponent("history"))
        let radio = RadioModel(preferences: preferences, cacheDirectory: directory.appendingPathComponent("feeds"), codexMonitor: monitor, fetcher: { _, _ in fatalError("No network feeds in this test") })
        var config = FeedConfiguration(); config.enabledChannels = ["codex"]
        radio.configuration = config
        precondition(radio.setupOpen && !monitor.enabled && monitor.snapshot == nil)
        print("PASS Codex monitor stays inactive until setup is complete")
        precondition(radio.finishSetup(configuration: config, language: .english) == nil)
        await wait { monitor.snapshot != nil }
        precondition(monitor.enabled && monitor.snapshot?.issue == .noLogs)
        print("PASS finishing setup starts local collection for an enabled station")
        monitor.window = .hour; monitor.step(1)
        precondition(monitor.window == .second)
        monitor.selectSession("specific-chat")
        monitor.showEdgePreview = false
        let second = CodexMonitorModel(preferences: preferences, historyDirectory: directory)
        precondition(second.window == .second && second.rootDirectory.path == root.path && second.selectedSessionID == "specific-chat" && !second.showEdgePreview)
        monitor.setRoot(directory.appendingPathComponent("missing"))
        precondition(monitor.snapshot == nil && monitor.selectedSessionID == nil && monitor.sessionNames.isEmpty)
        await wait { monitor.snapshot?.issue == .missingFolder }
        precondition(monitor.rootDirectory.path == preferences.string(forKey: "codexRootPath"))
        print("PASS source changes invalidate the old reading and persist folder/window choices")
        let sample = CodexMonitorModel(preferences: preferences, historyDirectory: directory, simulated: true)
        let choices = sample.sessions(now: Date())
        precondition(choices.count == 2)
        sample.selectSession(choices[0].id)
        precondition(!sample.scopedEvents.isEmpty && sample.scopedEvents.allSatisfy { $0.sessionID == choices[0].id })
        sample.selectSession("expired-chat")
        precondition(sample.scopedEvents.isEmpty && sample.selectedSessionID == "expired-chat")
        sample.selectSession(nil)
        precondition(sample.scopedEvents == sample.snapshot?.events)
        print("PASS chat scope persists, filters independently, and never falls back when selected activity expires")
        radio.configuration.enabledChannels = ["ai"]
        let checked = monitor.snapshot?.checkedAt
        precondition(!monitor.enabled)
        monitor.refresh()
        try? await Task.sleep(nanoseconds: 10_000_000)
        precondition(monitor.snapshot?.checkedAt == checked)
        print("PASS disabled local monitoring cannot be restarted by refresh")
        var temporary: CodexMonitorModel? = CodexMonitorModel(preferences: preferences, historyDirectory: directory)
        weak var released = temporary
        temporary?.configure(enabled: true, visible: true)
        temporary = nil
        await Task.yield()
        precondition(released == nil, "Polling must not retain its owner")
        print("PASS polling task does not retain a discarded monitor")
    }
}
