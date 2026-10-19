import Foundation

enum SetupLifecycle {
    static let completedKey = "setupCompleted"
    static func shouldPresent(_ defaults: UserDefaults, hasCachedEdition: Bool = false) -> Bool {
        if defaults.object(forKey: completedKey) != nil { return !defaults.bool(forKey: completedKey) }
        let existing = hasCachedEdition || ["stationConfiguration", "language", "translateArticles", "appearance", "channel", "edge", "antenna.x", "antenna.y", "antenna.monitorID", "pinned", "quantity", "refreshMinutes", "customFeedURL", "githubQuery"]
            .contains { defaults.object(forKey: $0) != nil }
        // Write the first-run marker before other defaults can make this look like an upgrade.
        defaults.set(existing, forKey: completedKey)
        return !existing
    }
    static func complete(_ defaults: UserDefaults) { defaults.set(true, forKey: completedKey) }
}
