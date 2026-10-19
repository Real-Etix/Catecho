import AppKit
import SwiftUI

@MainActor
final class ControlledFeed {
    var pending: [CheckedContinuation<FeedBatch, Error>] = []
    func fetch(_ channel: RadioChannel, _ config: FeedConfiguration) async throws -> FeedBatch {
        try await withCheckedThrowingContinuation { pending.append($0) }
    }
}

@main
struct ModelTests {
    @MainActor static func wait(_ predicate: () -> Bool) async {
        for _ in 0..<1000 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        fatalError("Timed out waiting for test request")
    }
    @MainActor static func main() async {
        UserDefaults.standard.removePersistentDomain(forName: "LittleRadio.Preview")
        defer { UserDefaults.standard.removePersistentDomain(forName: "LittleRadio.Preview") }
        let fake = ControlledFeed()
        let model = RadioModel(preview: true, fetcher: fake.fetch)
        model.channel = .github
        model.configuration = FeedConfiguration(githubQuery: "stars:>10", customFeedURL: "")
        model.refresh()
        await wait { fake.pending.count == 1 }
        precondition(model.isFetching)
        _ = model.saveSources(query: "stars:>20", feed: "")
        await wait { fake.pending.count == 2 }
        fake.pending[0].resume(throwing: CancellationError())
        try? await Task.sleep(nanoseconds: 10_000_000)
        precondition(model.isFetching, "Cancelled request must not clear replacement request's loading state")
        print("PASS superseded request cannot stop the tuning animation")
        let story = RadioItem(id: "one", title: "One", excerpt: "A source excerpt", source: "Fixture", url: URL(string: "https://example.com/one")!, publishedAt: nil, metric: nil)
        let edition = FeedBatch(items: [story], fetchedAt: Date(), warning: nil)
        fake.pending[1].resume(returning: edition)
        await wait { !model.isFetching }
        precondition(model.items == [story])
        print("PASS replacement request publishes the correct edition")
        model.refresh()
        await wait { fake.pending.count == 3 }
        fake.pending[2].resume(throwing: FeedError.message("Offline test"))
        await wait { !model.isFetching }
        precondition(model.items == [story] && model.failures[.github] == "Offline test")
        print("PASS failed refresh preserves readable cached content and stops loading")
        model.refresh()
        model.refresh()
        await wait { fake.pending.count == 4 }
        try? await Task.sleep(nanoseconds: 10_000_000)
        precondition(fake.pending.count == 4)
        fake.pending[3].resume(returning: edition)
        await wait { !model.isFetching }
        print("PASS repeated refresh clicks share one request")
        let stories = (1...5).map { index in
            RadioItem(id: "story-\(index)", title: "Story \(index)", excerpt: "Excerpt", source: "Fixture", url: URL(string: "https://example.com/\(index)")!, publishedAt: nil, metric: nil)
        }
        model.quantity = 5
        model.batches[.github] = FeedBatch(items: stories, fetchedAt: Date(), warning: nil)
        model.positions[.github] = 0
        model.refresh()
        await wait { fake.pending.count == 5 }
        model.step(1)
        model.step(1)
        fake.pending[4].resume(returning: FeedBatch(items: stories.reversed(), fetchedAt: Date(), warning: nil))
        await wait { !model.isFetching }
        precondition(model.item?.id == "story-3", "Refresh must preserve the story selected while fetching")
        print("PASS refresh preserves reading progress made during fetch")

        model.positions[.github] = 4
        model.refresh()
        await wait { fake.pending.count == 6 }
        model.quantity = 3
        model.channel = .ai
        model.batches[.ai] = FeedBatch(items: [story], fetchedAt: Date(), warning: nil)
        fake.pending[5].resume(returning: FeedBatch(items: stories, fetchedAt: Date(), warning: nil))
        await wait { !model.fetching.contains(.github) }
        model.channel = .github
        precondition(model.item?.id == "story-3", "Background refresh must use its own channel and current visible quantity")
        print("PASS background refresh preserves its channel selection after quantity change")

        for c in RadioChannel.allCases { model.batches[c] = edition }
        model.configuration.customFeedURL = ""
        model.channel = .ai
        model.cycleChannel()
        precondition(model.channel == .github, "A dial click must advance directly to GitHub")
        model.cycleChannel()
        precondition(model.channel == .research)
        model.cycleChannel()
        precondition(model.channel == .ai, "An unconfigured custom feed must be skipped")
        print("PASS one-click channel cycle wraps and skips unconfigured feed")
        model.configuration.customFeedURL = "https://example.com/feed.xml"
        model.channel = .research
        model.cycleChannel()
        precondition(model.channel == .custom)
        model.cycleChannel()
        precondition(model.channel == .ai)
        print("PASS configured custom feed participates in channel cycle")
        model.batches[.ai] = FeedBatch(items: stories, fetchedAt: Date(), warning: nil)
        model.positions[.ai] = 1
        for _ in 0..<4 { model.cycleChannel() }
        precondition(model.channel == .ai && model.item?.id == "story-2")
        print("PASS channel cycle preserves reading position")

        let selection = Data(#"{"githubQuery":"stars:>10000","customFeedURL":"","enabledChannels":["games","research"]}"#.utf8)
        model.configuration = try! JSONDecoder().decode(FeedConfiguration.self, from: selection)
        precondition(model.channels.map(\.rawValue) == ["research", "games"], "Only enabled presets should appear on the dial, in catalog order")
        print("PASS station selection controls dial choices")

        let instant = RadioModel(preview: true, fetcher: { _, _ in edition })
        var preferences = FeedConfiguration()
        preferences.enabledChannels = ["research", "games"]
        preferences.customStations = [CustomStation(id: "physics-notes", title: "Physics notebook", feedURLs: ["https://example.com/feed"], keywords: "quantum, AI")]
        instant.channel = .ai
        precondition(instant.saveConfiguration(preferences) == nil)
        precondition(instant.channel == .research)
        precondition(instant.channels.map(\.rawValue) == ["research", "games", "custom:physics-notes"])
        instant.choose(.station("physics-notes"))
        precondition(instant.channelTitle == "Physics notebook")
        instant.choose(.ai)
        precondition(instant.channel == .station("physics-notes"), "Disabled channels cannot be selected")
        let restored = RadioModel(preview: true, fetcher: { _, _ in edition })
        precondition(restored.configuration == preferences && restored.channel == .station("physics-notes"))
        print("PASS custom stations, disabled selection fallback and preferences survive relaunch")

        var invalid = preferences
        invalid.customStations[0].feedURLs = ["https://name:password@example.com/feed"]
        precondition(instant.saveConfiguration(invalid) != nil && instant.configuration == preferences)
        invalid = preferences; invalid.enabledChannels = []; invalid.customStations = []
        precondition(instant.saveConfiguration(invalid) != nil)
        invalid = preferences; invalid.customStations.append(invalid.customStations[0])
        precondition(instant.saveConfiguration(invalid) != nil)
        invalid = preferences; invalid.customFeedURL = "http://example.com/feed"
        precondition(instant.saveConfiguration(invalid) != nil)
        print("PASS invalid and empty station configurations do not replace saved preferences")

        let liveFeed = ControlledFeed()
        let sports = RadioModel(preview: true, fetcher: liveFeed.fetch)
        sports.configuration = FeedConfiguration()
        sports.configuration.enabledChannels = ["nba"]
        sports.channel = .nba; sports.refreshMinutes = 60; sports.isExpanded = true
        sports.batches[.nba] = FeedBatch(items: [story], fetchedAt: Date(), warning: nil)
        sports.periodicRefresh(now: Date().addingTimeInterval(61))
        await wait { liveFeed.pending.count == 1 }
        liveFeed.pending[0].resume(returning: edition)
        await wait { !sports.isFetching }
        sports.isExpanded = false
        sports.periodicRefresh(now: Date().addingTimeInterval(65))
        try? await Task.sleep(nanoseconds: 10_000_000)
        precondition(liveFeed.pending.count == 1, "Tucked NBA uses normal background interval")
        sports.isExpanded = true; sports.settingsOpen = true
        sports.periodicRefresh(now: Date().addingTimeInterval(65))
        try? await Task.sleep(nanoseconds: 10_000_000)
        precondition(liveFeed.pending.count == 1, "Service compartment pauses rapid NBA polling")
        sports.settingsOpen = false; sports.refreshMinutes = 0
        sports.periodicRefresh(now: Date().addingTimeInterval(4000))
        try? await Task.sleep(nanoseconds: 10_000_000)
        precondition(liveFeed.pending.count == 1, "Manual mode disables periodic polling")
        print("PASS NBA minute polling is limited to visible station with automatic updates enabled")

        let status = RadioModel(preview: true, fetcher: liveFeed.fetch)
        status.configuration = FeedConfiguration(); status.configuration.enabledChannels = ["ai", "nba"]
        status.channel = .nba; status.refreshMinutes = 60; status.isExpanded = true
        let received = Date(timeIntervalSince1970: 1_700_000_000)
        status.batches = [.ai: FeedBatch(items: [story], fetchedAt: received, warning: nil), .nba: FeedBatch(items: [story], fetchedAt: received, warning: nil), .games: edition]
        precondition(status.lastReceivedAt == received, "Disabled stations cannot supply the latest update")
        precondition(status.nextRefreshAt(now: received) == received.addingTimeInterval(60))
        status.settingsOpen = true
        precondition(status.nextRefreshAt(now: received) == received.addingTimeInterval(3600))
        precondition(status.nextRefreshAt(now: received.addingTimeInterval(4000)) == received.addingTimeInterval(4000), "Overdue checks display as due, not a past appointment")
        status.refreshMinutes = 0
        precondition(status.nextRefreshAt(now: received) == nil)
        status.refreshMinutes = 60
        status.batches[.nba] = nil
        precondition(status.nextRefreshAt(now: received) == received, "Missing editions are due immediately")
        status.prepareEdition(); status.prepareEdition()
        await wait { liveFeed.pending.count == 3 }
        precondition(status.fetching.count == 2 && status.channel == .nba)
        precondition(status.nextRefreshAt(now: received) == nil, "In-flight stations have no pending check")
        liveFeed.pending[1].resume(returning: FeedBatch(items: [story], fetchedAt: received.addingTimeInterval(30), warning: nil))
        liveFeed.pending[2].resume(throwing: FeedError.message("Offline test"))
        await wait { status.fetching.isEmpty }
        precondition(status.lastReceivedAt == received.addingTimeInterval(30) && status.receptionIssueCount == 1)
        print("PASS reception status follows real enabled-station schedule, manual mode, failures and coalesced Refresh all")

        let local = RadioModel(preview: true, fetcher: { _, _ in fatalError("Local monitor must never fetch a network feed") })
        local.configuration = FeedConfiguration()
        local.configuration.enabledChannels = ["codex"]
        precondition(local.channels.map(\.rawValue) == ["codex"], "Codex must be a selectable station")
        local.channel = local.channels[0]
        local.prepareEdition(); local.refresh(); local.periodicRefresh(now: Date().addingTimeInterval(8000))
        await Task.yield()
        precondition(local.fetching.isEmpty && local.receptionPendingCount == 0)
        precondition(local.lastReceivedAt == nil && local.nextRefreshAt() == nil && local.receptionIssueCount == 0)
        print("PASS local Codex station never enters feed fetching or reception scheduling")

        var webPreferences = preferences
        webPreferences.customStations = [CustomStation(id: "web", title: "Website", feedURLs: [], webpageURLs: ["https://example.com/news"])]
        precondition(instant.saveConfiguration(webPreferences) == nil, "Webpage-only stations must be valid")
        await wait { instant.fetching.isEmpty }
        let restoredWeb = RadioModel(preview: true)
        precondition(restoredWeb.configuration.customStations.first?.webpageURLs == ["https://example.com/news"])
        var invalidWeb = webPreferences
        invalidWeb.customStations[0].webpageURLs = ["https://user:password@example.com/news"]
        precondition(instant.saveConfiguration(invalidWeb) != nil && instant.configuration == webPreferences)
        invalidWeb.customStations[0].webpageURLs = Array(repeating: "https://example.com/news", count: 9)
        precondition(instant.saveConfiguration(invalidWeb) != nil)
        print("PASS webpage-only settings persist; unsafe and oversized source lists rejected")

    }
}
