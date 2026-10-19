import AppKit
import SwiftUI
import CryptoKit

/// Owns one local reader. Cancelling/reconfiguring invalidates in-flight snapshots.
@MainActor final class CodexMonitorModel: ObservableObject {
    @Published private(set) var snapshot: CodexUsageSnapshot?
    @Published private(set) var rootDirectory: URL
    @Published private(set) var enabled = false
    @Published var isChatPickerPresented = false
    @Published private(set) var selectedSessionID: String?
    @Published private(set) var sessionNames: [String: String] = [:]
    @Published var showEdgePreview: Bool { didSet { preferences.set(showEdgePreview, forKey: "codexEdgePreview") } }
    @Published var window: CodexUsageWindow { didSet { preferences.set(window.rawValue, forKey: "codexWindow") } }
    let simulated: Bool
    private let preferences: UserDefaults
    private let historyDirectory: URL
    private var collector: CodexUsageCollector?
    private let titleIndex = CodexSessionIndex()
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var visible = false

    init(preferences: UserDefaults, historyDirectory: URL, simulated: Bool = false) {
        self.preferences = preferences
        self.historyDirectory = historyDirectory
        self.simulated = simulated
        rootDirectory = preferences.string(forKey: "codexRootPath").map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultRoot
        window = CodexUsageWindow(rawValue: preferences.string(forKey: "codexWindow") ?? "lifetime") ?? .lifetime
        selectedSessionID = preferences.string(forKey: "codexSessionID").flatMap { !$0.isEmpty && $0.utf8.count <= 256 ? $0 : nil }
        showEdgePreview = preferences.object(forKey: "codexEdgePreview") == nil ? true : preferences.bool(forKey: "codexEdgePreview")
        if simulated { snapshot = Self.sample(); sessionNames = ["preview-ai": "AI research notes", "preview-radio": "Building a quiet radio", "preview-old": "An earlier physics chat"] }
    }
    deinit { task?.cancel() }
    static var defaultRoot: URL {
        if let path = ProcessInfo.processInfo.environment["CODEX_HOME"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }
    func configure(enabled: Bool, visible: Bool) {
        let changed = self.enabled != enabled || self.visible != visible
        self.enabled = enabled; self.visible = visible
        if !visible { isChatPickerPresented = false }
        guard changed else { return }
        restart()
    }
    func step(_ direction: Int) {
        let choices = CodexUsageWindow.allCases
        let index = choices.firstIndex(of: window) ?? 0
        window = choices[(index + direction + choices.count) % choices.count]
    }
    func refresh() { restart() }
    func selectSession(_ id: String?) {
        guard id == nil || (id!.utf8.count <= 256 && !id!.isEmpty) else { return }
        selectedSessionID = id
        if let id { preferences.set(id, forKey: "codexSessionID") } else { preferences.removeObject(forKey: "codexSessionID") }
    }
    var scopedEvents: [CodexUsageEvent] { CodexSessionSummary.filter(snapshot?.events ?? [], sessionID: selectedSessionID) }
    var scopedLastRecordedAt: Date? {
        if window == .lifetime { return snapshot?.lifetimeSessions?.filter { selectedSessionID == nil || $0.id == selectedSessionID }.map(\.lastRecordedAt).max() }
        return scopedEvents.map(\.recordedAt).max()
    }
    func sessions(now: Date) -> [CodexSessionSummary] { snapshot?.lifetimeSessions ?? [] }
    func lifetimeUsage(sessionID: String?) -> CodexTokenUsage? {
        guard let snapshot, let sessions = snapshot.lifetimeSessions else { return nil }
        let matching = sessions.filter { sessionID == nil || $0.id == sessionID }
        guard !matching.isEmpty || (snapshot.issue == nil && !snapshot.isIndexing) else { return nil }
        return CodexSessionSummary.combinedUsage(matching)
    }
    var lifetimeEmptyMessage: String {
        if snapshot == nil || snapshot?.isIndexing == true { return "Reading local records…" }
        return lifetimeUsage(sessionID: nil) == nil ? "Lifetime total unavailable" : "No recorded activity yet"
    }
    var readingUnavailable: Bool {
        if window == .lifetime { return lifetimeUsage(sessionID: selectedSessionID) == nil }
        return snapshot == nil || (snapshot?.issue != nil && scopedEvents.isEmpty)
    }
    func usage(now: Date) -> CodexTokenUsage {
        guard window == .lifetime else { return window.total(scopedEvents, now: now) }
        return lifetimeUsage(sessionID: selectedSessionID) ?? CodexTokenUsage(input: 0, cachedInput: 0, output: 0, reasoning: 0)
    }
    func title(for id: String?, language: RadioLanguage) -> String {
        guard let id else { return language.text("All chats") }
        return sessionNames[id] ?? language.text("Session") + " · " + id.suffix(8)
    }
    func reading(now: Date, compact: Bool = false) -> String {
        guard !readingUnavailable else { return "—" }
        let total = usage(now: now).total
        if window == .second { return (Double(total) / 60).formatted(.number.precision(.fractionLength(1)).notation(compact ? .compactName : .automatic)) }
        return compact ? total.formatted(.number.notation(.compactName)) : total.formatted()
    }
    func useDefaultFolder() { setRoot(Self.defaultRoot) }
    func chooseFolder(language: RadioLanguage) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false; panel.showsHiddenFiles = true
        panel.directoryURL = rootDirectory
        panel.message = language.text("Choose the Codex home folder containing sessions.")
        panel.prompt = language.text("Use folder")
        if panel.runModal() == .OK, let url = panel.url { setRoot(url) }
    }
    func setRoot(_ url: URL) {
        let next = url.standardizedFileURL
        guard next != rootDirectory else { return }
        rootDirectory = next
        preferences.set(next.path, forKey: "codexRootPath")
        selectSession(nil); sessionNames = [:]
        collector = nil; snapshot = simulated ? Self.sample() : nil
        restart()
    }
    private func restart() {
        task?.cancel(); task = nil
        generation = UUID()
        guard enabled, !simulated else { return }
        if collector == nil {
            let key = SHA256.hash(data: Data(rootDirectory.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
            collector = CodexUsageCollector(rootDirectory: rootDirectory, historyURL: historyDirectory.appendingPathComponent("codex-\(key).json"))
        }
        guard let collector else { return }
        let generation = generation
        let titleIndex = titleIndex
        let root = rootDirectory
        // The actor performs disk IO away from the main actor; weak capture avoids a loop retaining its owner.
        task = Task { [weak self] in
            while !Task.isCancelled {
                let value = await collector.poll()
                guard !Task.isCancelled, self?.generation == generation else { return }
                self?.snapshot = value
                let names = await titleIndex.names(root: root)
                guard !Task.isCancelled, self?.generation == generation else { return }
                self?.sessionNames = names
                let delay: UInt64 = value.isIndexing ? 10_000_000 : (self?.visible == true ? 1_000_000_000 : 5_000_000_000)
                do { try await Task.sleep(nanoseconds: delay) } catch { return }
            }
        }
    }
    private static func sample() -> CodexUsageSnapshot {
        let now = Date()
        var events: [CodexUsageEvent] = []
        for i in 0..<160 {
            let age = Double(i * (i < 12 ? 4 : 510))
            let usage = CodexTokenUsage(input: Int64(1800 + (i % 7) * 750), cachedInput: 1200, output: Int64(110 + (i % 5) * 70), reasoning: 80)
            events.append(CodexUsageEvent(id: "preview-\(i)", sessionID: i % 3 == 0 ? "preview-ai" : "preview-radio", recordedAt: now.addingTimeInterval(-age), usage: usage))
        }
        var totals = CodexSessionSummary.summaries(events, now: now).map { s in
            CodexSessionSummary(id: s.id, lastRecordedAt: s.lastRecordedAt, usage: CodexTokenUsage(input: s.usage.input + 24_000_000, cachedInput: s.usage.cachedInput + 12_000_000, output: s.usage.output + 900_000, reasoning: s.usage.reasoning + 200_000))
        }
        totals.append(CodexSessionSummary(id: "preview-old", lastRecordedAt: now.addingTimeInterval(-300_000), usage: CodexTokenUsage(input: 4_000_000, cachedInput: 2_000_000, output: 100_000, reasoning: 20_000)))
        return CodexUsageSnapshot(events: events, checkedAt: now, lastRecordedAt: now, isIndexing: false, filesScanned: 4, filesTotal: 4, issue: nil, warning: nil, bytesRead: 0, lifetimeSessions: totals)
    }
}
