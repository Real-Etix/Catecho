import AppKit
import SwiftUI
import CryptoKit

/// Owns one local reader. Cancelling/reconfiguring invalidates in-flight snapshots.
@MainActor final class CodexMonitorModel: ObservableObject {
    @Published private(set) var snapshot: CodexUsageSnapshot?
    @Published private(set) var rootDirectory: URL
    @Published private(set) var enabled = false
    @Published var window: CodexUsageWindow { didSet { preferences.set(window.rawValue, forKey: "codexWindow") } }
    let simulated: Bool
    private let preferences: UserDefaults
    private let historyDirectory: URL
    private var collector: CodexUsageCollector?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var visible = false

    init(preferences: UserDefaults, historyDirectory: URL, simulated: Bool = false) {
        self.preferences = preferences
        self.historyDirectory = historyDirectory
        self.simulated = simulated
        rootDirectory = preferences.string(forKey: "codexRootPath").map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultRoot
        window = CodexUsageWindow(rawValue: preferences.string(forKey: "codexWindow") ?? "second") ?? .second
        if simulated { snapshot = Self.sample() }
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
        guard changed else { return }
        restart()
    }
    func step(_ direction: Int) {
        let choices = CodexUsageWindow.allCases
        let index = choices.firstIndex(of: window) ?? 0
        window = choices[(index + direction + choices.count) % choices.count]
    }
    func refresh() { restart() }
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
        // The actor performs disk IO away from the main actor; weak capture avoids a loop retaining its owner.
        task = Task { [weak self] in
            while !Task.isCancelled {
                let value = await collector.poll()
                guard !Task.isCancelled, self?.generation == generation else { return }
                self?.snapshot = value
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
            events.append(CodexUsageEvent(id: "preview-\(i)", sessionID: "preview", recordedAt: now.addingTimeInterval(-age), usage: usage))
        }
        return CodexUsageSnapshot(events: events, checkedAt: now, lastRecordedAt: now, isIndexing: false, filesScanned: 4, filesTotal: 4, issue: nil, warning: nil, bytesRead: 0)
    }
}
