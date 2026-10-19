import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { print("FAIL setup: " + message); exit(1) }
    print("PASS setup: " + message)
}

@main struct SetupTests {
    @MainActor static func main() async {
        let name = "Catecho.SetupTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        check(SetupLifecycle.shouldPresent(defaults), "fresh installation presents setup")
        defaults.set("en", forKey: "language")
        check(SetupLifecycle.shouldPresent(defaults), "interrupted setup is not mistaken for an existing user")
        SetupLifecycle.complete(defaults)
        check(!SetupLifecycle.shouldPresent(defaults), "completed setup does not repeat")
        defaults.removePersistentDomain(forName: name)
        defaults.set("Flat", forKey: "appearance")
        check(!SetupLifecycle.shouldPresent(defaults), "existing installation migrates without onboarding")
        check(defaults.string(forKey: "appearance") == "Flat", "migration preserves preferences")
        for key in ["translateArticles", "edge", "antenna.y", "antenna.monitorID"] {
            defaults.removePersistentDomain(forName: name)
            defaults.set(false, forKey: key)
            check(!SetupLifecycle.shouldPresent(defaults), "migration recognizes legacy preference " + key)
        }
        print("PASS setup lifecycle")
        defaults.removePersistentDomain(forName: name)
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defer { try? FileManager.default.removeItem(at: cache) }
        var requested: [RadioChannel] = []
        let fetch: (RadioChannel, FeedConfiguration) async throws -> FeedBatch = { channel, _ in
            requested.append(channel)
            return FeedBatch(items: [], fetchedAt: Date(), warning: nil)
        }
        let model = RadioModel(preferences: defaults, cacheDirectory: cache, fetcher: fetch)
        check(model.setupOpen, "new model starts in setup")
        model.prepareEdition(); model.refresh(); model.refreshIfNeeded(); model.periodicRefresh()
        try? await Task.sleep(nanoseconds: 20_000_000)
        check(requested.isEmpty, "no default-source requests before choices are finished")
        var invalid = model.configuration
        invalid.enabledChannels = []
        check(model.finishSetup(configuration: invalid, language: .traditional) != nil, "empty station selection is rejected")
        check(model.setupOpen && !model.hasCompletedSetup && model.language == .system, "validation failure keeps setup and original language")
        var selection = model.configuration
        selection.enabledChannels = ["research", "science"]
        selection.researchTopics = ["quant-ph", "cs.LG"]
        check(model.finishSetup(configuration: selection, language: .traditional) == nil, "chosen stations and language can finish setup")
        check(!model.setupOpen && model.hasCompletedSetup, "finish closes setup and persists completion")
        for _ in 0..<100 { if requested.count == 2 { break }; try? await Task.sleep(nanoseconds: 1_000_000) }
        check(Set(requested) == Set([.research, .science]), "finish warms every chosen station, not the defaults")
        let restored = RadioModel(preferences: defaults, cacheDirectory: cache, fetcher: fetch)
        check(!restored.setupOpen && restored.language == .traditional, "restart keeps language and skips completed setup")
        check(Set(restored.configuration.researchTopics) == Set(["quant-ph", "cs.LG"]), "research subjects persist")
        check(Set(restored.channels) == Set([.research, .science]), "station choices persist")
        restored.settingsOpen = true
        restored.beginSetup()
        check(!restored.setupOpen && restored.settingsOpen, "reopening cannot discard an open settings draft")
        restored.settingsOpen = false
        var revealed = false
        restored.onReveal = { revealed = true }
        restored.beginSetup()
        check(restored.setupOpen && revealed, "setup can be reopened from the menu")
        let before = restored.configuration
        restored.skipSetup()
        check(!restored.setupOpen && restored.configuration == before && restored.language == .traditional, "skip preserves current choices")
        defaults.removePersistentDomain(forName: name)
        let preview = RadioModel(preview: true, preferences: defaults, cacheDirectory: cache, fetcher: fetch)
        check(!preview.setupOpen && defaults.object(forKey: SetupLifecycle.completedKey) == nil, "previews do not migrate real first-run state")
        let cacheOnly = cache.appendingPathComponent("cache-only")
        try! RadioCache(directory: cacheOnly).save(FeedBatch(items: [], fetchedAt: Date(), warning: nil), channel: .ai, configuration: FeedConfiguration())
        let legacy = RadioModel(preferences: defaults, cacheDirectory: cacheOnly, fetcher: fetch)
        check(!legacy.setupOpen && legacy.hasCompletedSetup, "valid cached edition identifies an existing reader with no preferences")
        defaults.set(false, forKey: SetupLifecycle.completedKey)
        let interrupted = RadioModel(preferences: defaults, cacheDirectory: cacheOnly, fetcher: fetch)
        check(interrupted.setupOpen, "unfinished setup marker takes precedence over cache evidence")
        for key in ["Choose your topics", "Make it feel familiar", "Ready for your morning", "Start at login", "Start reading", "Open Login Items", "Set up your radio…"] {
            check(RadioLanguage.simplified.text(key) != key && RadioLanguage.traditional.text(key) != key, "both Chinese scripts translate " + key)
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}
