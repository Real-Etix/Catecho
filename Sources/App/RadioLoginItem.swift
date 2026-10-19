import Combine
import Foundation
import ServiceManagement

@MainActor
final class RadioLoginItem: ObservableObject {
    enum State { case off, on, approvalRequired, unavailable }
    @Published private(set) var state: State = .off
    @Published private(set) var errorKey: String?
    // A moved app may still withdraw an existing request, but cannot add one.
    var canChange: Bool { state != .unavailable && (isInstalled || isRequested) }
    var isRequested: Bool { state == .on || state == .approvalRequired }

    private let isInstalled: Bool
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void
    private let showSettings: () -> Void

    init(
        bundleURL: URL = Bundle.main.bundleURL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() },
        openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }
    ) {
        let app = bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        let parent = app.deletingLastPathComponent()
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true).resolvingSymlinksInPath()
        let userApplications = homeDirectory.appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        isInstalled = app.pathExtension.lowercased() == "app"
            && (parent.path == systemApplications.path || parent.path == userApplications.path)
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        self.showSettings = openSettings
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        // System Settings may have changed since this view was opened.
        refresh()
        errorKey = nil
        guard state != .unavailable else {
            errorKey = "Start at login is unavailable on this Mac."
            return
        }
        guard enabled != isRequested else { return }
        guard !enabled || isInstalled else {
            errorKey = "Move Catecho to Applications before enabling start at login."
            return
        }

        let failureKey = enabled
            ? "Could not enable start at login. Try again in System Settings."
            : "Could not disable start at login. Try again in System Settings."
        do {
            if enabled { try register() }
            else { try unregister() }
            refresh()
            // Successful API return does not mean the OS has enabled launch.
            // Approval is its own state and stays visible until macOS confirms it.
            if state == .unavailable {
                errorKey = "Start at login is unavailable on this Mac."
            } else if enabled != isRequested {
                errorKey = failureKey
            }
        } catch {
            refresh()
            errorKey = failureKey
        }
    }

    func refresh() {
        let latest: State
        switch readStatus() {
        case .notRegistered: latest = .off
        case .enabled: latest = .on
        case .requiresApproval: latest = .approvalRequired
        case .notFound: latest = .unavailable
        @unknown default: latest = .unavailable
        }
        if state != latest { errorKey = nil }
        state = latest
    }

    func openSettings() { showSettings() }
}
