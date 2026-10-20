import AppKit
import UserNotifications

@MainActor
final class ResetNotifications: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var enabled = false
    var status: ((String) -> Void)?
    var openStation: (() -> Void)?

    override init() {
        super.init()
        center.delegate = self
    }
    func configure(_ enabled: Bool) {
        self.enabled = enabled
        if !enabled {
            status?("Alerts are off")
            center.removeAllPendingNotificationRequests()
            return
        }
        Task {
            let settings = await center.notificationSettings()
            guard self.enabled else { return }
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert])
            }
            await refreshStatus()
        }
    }
    func refreshStatus() async {
        let settings = await center.notificationSettings()
        guard enabled else { status?("Alerts are off"); return }
        status?(settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                ? "Notifications are allowed" : "Allow Catecho notifications in System Settings.")
    }
    func send(_ item: RadioItem, language: RadioLanguage) {
        guard enabled else { return }
        Task {
            let settings = await center.notificationSettings()
            guard enabled, settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = language.text(item.title)
            content.subtitle = "Tibo · Codex Resets"
            content.body = String(item.excerpt.prefix(180))
            content.userInfo = ["station": "resets"]
            let request = UNNotificationRequest(identifier: "catecho-" + item.id, content: content, trigger: nil)
            do { try await center.add(request) }
            catch { status?("The notification could not be delivered.") }
        }
    }
    func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            if response.notification.request.content.userInfo["station"] as? String == "resets" { self.openStation?() }
            completionHandler()
        }
    }
}
