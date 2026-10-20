import AppKit
import SwiftUI

@MainActor
final class RadioModel: ObservableObject {
    @Published var language: RadioLanguage { didSet { defaults.set(language.rawValue, forKey: "language"); onLanguageChange?() } }
    @Published var translateArticles: Bool { didSet { defaults.set(translateArticles, forKey: "translateArticles") } }
    var onLanguageChange: (() -> Void)?
    func t(_ text: String) -> String { language.text(text) }
    var channelTitle: String { title(for: channel) }
    func title(for channel: RadioChannel) -> String {
        configuration.customStations.first { RadioChannel.station($0.id) == channel }?.title ?? t(channel.title)
    }
    @Published var appearance: String { didSet { defaults.set(appearance, forKey: "appearance") } }
    @Published var edge: String { didSet { defaults.set(edge, forKey: "edge"); onPlacementChange?() } }
    @Published var pinned: Bool { didSet { defaults.set(pinned, forKey: "pinned") } }
    @Published var quantity: Int { didSet { defaults.set(quantity, forKey: "quantity") } }
    @Published var refreshMinutes: Int { didSet { defaults.set(refreshMinutes, forKey: "refreshMinutes") } }
    @Published var channel: RadioChannel { didSet { defaults.set(channel.rawValue, forKey: "channel"); syncCodex() } }
    @Published var configuration: FeedConfiguration { didSet {
        syncCodex()
        let wasActive = oldValue.resetAlerts && oldValue.enabledChannels.contains("resets")
        if wasActive != resetAlertsActive {
            resetLedger = ResetAlertLedger()
            defaults.removeObject(forKey: "resetAlertLedger")
            onResetAlertsChange?(resetAlertsActive)
        }
    } }
    @Published var resetNotificationStatus = "Alerts are off"
    var onResetAlertsChange: ((Bool) -> Void)?
    var onResetAnnouncement: ((RadioItem) -> Void)?
    var onNotificationSettings: (() -> Void)?
    private var resetLedger = ResetAlertLedger()
    var resetAlertsActive: Bool { configuration.resetAlerts && configuration.enabledChannels.contains("resets") }
    @Published var batches: [RadioChannel: FeedBatch] = [:]
    @Published var failures: [RadioChannel: String] = [:]
    @Published var fetching: Set<RadioChannel> = []
    @Published var positions: [RadioChannel: Int] = [:]
    @Published var isExpanded = false { didSet { syncCodex() } }
    @Published var botExpanded = false
    @Published var botRoomReserved = false
    @Published var botOriginCorrection: CGFloat = 0
    @Published var botVerticalCorrection: CGFloat = 0
    @Published var settingsOpen = false { didSet { syncCodex() } }
    @Published private(set) var setupOpen = false { didSet { syncCodex() } }
    @Published var cacheWarning: String?
    var onPlacementChange: (() -> Void)?
    var onTuck: (() -> Void)?
    var onReveal: (() -> Void)?
    var onBotExpansion: ((Bool) -> Void)?
    var onBotDragBegan: (() -> Void)?
    var onBotDragEnded: (() -> Void)?
    var onWindowDragFinished: (() -> Void)?
    let codex: CodexMonitorModel
    private let defaults: UserDefaults
    private let cache: RadioCache
    private let fetcher: (RadioChannel, FeedConfiguration) async throws -> FeedBatch
    private var tasks: [RadioChannel: Task<Void, Never>] = [:]
    private var requestIDs: [RadioChannel: UUID] = [:]
    private var lastAttempts: [RadioChannel: Date] = [:]

    init(preview: Bool = false, preferences: UserDefaults? = nil, cacheDirectory: URL? = nil, codexMonitor: CodexMonitorModel? = nil, fetcher: @escaping (RadioChannel, FeedConfiguration) async throws -> FeedBatch = { try await FeedService().fetch(channel: $0, configuration: $1) }) {
        self.fetcher = fetcher
        defaults = preferences ?? (preview ? UserDefaults(suiteName: "LittleRadio.Preview")! : .standard)
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Little Radio/Usage")
        codex = codexMonitor ?? CodexMonitorModel(preferences: defaults, historyDirectory: supportDirectory, simulated: preview || preferences != nil)
        language = RadioLanguage(rawValue: defaults.string(forKey: "language") ?? "system") ?? .system
        translateArticles = defaults.object(forKey: "translateArticles") == nil ? true : defaults.bool(forKey: "translateArticles")
        appearance = defaults.string(forKey: "appearance") ?? "Classic"
        edge = defaults.string(forKey: "edge") ?? "Right"
        pinned = defaults.object(forKey: "pinned") == nil ? true : defaults.bool(forKey: "pinned")
        quantity = [3, 5, 8].contains(defaults.integer(forKey: "quantity")) ? defaults.integer(forKey: "quantity") : 5
        refreshMinutes = defaults.object(forKey: "refreshMinutes") == nil ? 60 : defaults.integer(forKey: "refreshMinutes")
        channel = RadioChannel(rawValue: defaults.string(forKey: "channel") ?? "ai") ?? .ai
        configuration = defaults.data(forKey: "stationConfiguration").flatMap { try? JSONDecoder().decode(FeedConfiguration.self, from: $0) }
            ?? FeedConfiguration(githubQuery: defaults.string(forKey: "githubQuery") ?? "stars:>10000", customFeedURL: defaults.string(forKey: "customFeedURL") ?? "")
        resetLedger = defaults.data(forKey: "resetAlertLedger").flatMap { try? JSONDecoder().decode(ResetAlertLedger.self, from: $0) } ?? ResetAlertLedger()
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cache = RadioCache(directory: cacheDirectory ?? (preview ? FileManager.default.temporaryDirectory.appendingPathComponent("LittleRadioPreview") : support.appendingPathComponent("Little Radio/Cache")))
        if !preview {
            for c in feedChannels { batches[c] = cache.load(channel: c, configuration: configuration) }
        }
        let needsSetup = !preview && SetupLifecycle.shouldPresent(defaults, hasCachedEdition: !batches.isEmpty)
        if !channels.contains(channel) { channel = channels.first ?? .ai }
        setupOpen = needsSetup
        syncCodex()
    }

    var hasCompletedSetup: Bool { defaults.bool(forKey: SetupLifecycle.completedKey) }
    func beginSetup() {
        guard !settingsOpen, !setupOpen else { return }
        setupOpen = true
        onReveal?()
    }
    func finishSetup(configuration candidate: FeedConfiguration, language choice: RadioLanguage) -> String? {
        guard let error = saveConfiguration(candidate, refreshAfterSave: false) else {
            // Unchanged default choices still need a persistent configuration on first use.
            defaults.set(try? JSONEncoder().encode(configuration), forKey: "stationConfiguration")
            language = choice
            leaveSetup()
            return nil
        }
        return error
    }
    func skipSetup() { leaveSetup() }
    private func leaveSetup() {
        SetupLifecycle.complete(defaults)
        setupOpen = false
        prepareEdition()
    }

    var channels: [RadioChannel] {
        var choices = StationCatalog.presets.filter { configuration.enabledChannels.contains($0.rawValue) }
        if !configuration.customFeedURL.isEmpty { choices.append(.custom) }
        choices += configuration.customStations.filter(\.enabled).map { RadioChannel.station($0.id) }
        return choices
    }
    private func syncCodex() {
        codex.configure(enabled: !setupOpen && configuration.enabledChannels.contains("codex"), visible: isExpanded && !settingsOpen && !setupOpen && channel == .codex)
    }
    var feedChannels: [RadioChannel] { channels.filter { $0 != .codex } }
    private func displayItems(_ batch: FeedBatch?, channel: RadioChannel) -> [RadioItem] {
        let all = batch?.items ?? []
        if channel == .stocks { return all.filter { $0.stockQuote != nil } + all.filter { $0.stockQuote == nil }.prefix(quantity) }
        return Array(all.prefix(quantity))
    }
    var items: [RadioItem] { displayItems(batches[channel], channel: channel) }
    var currentIndex: Int { min(positions[channel] ?? 0, max(0, items.count - 1)) }
    var item: RadioItem? { items.isEmpty ? nil : items[currentIndex] }
    var isFetching: Bool { fetching.contains(channel) }
    var isClassic: Bool { appearance == "Classic" }
    var statusMessage: String? { (failures[channel] ?? batches[channel]?.warning ?? cacheWarning).map(t) }
    var isStale: Bool { batches[channel].map { Date().timeIntervalSince($0.fetchedAt) > 3600 } ?? true }
    /// Most recent successful station response, not a claim that every station is up to date.
    var lastReceivedAt: Date? { feedChannels.compactMap { batches[$0]?.fetchedAt }.max() }
    var receptionIssueCount: Int {
        feedChannels.filter { failures[$0] != nil || batches[$0]?.warning != nil }.count
    }
    var receptionPendingCount: Int { feedChannels.filter { batches[$0] == nil }.count }
    private func refreshInterval(for choice: RadioChannel) -> TimeInterval {
        if choice == .resets && resetAlertsActive { return 300 }
        if choice == channel && isExpanded && !settingsOpen {
            if choice == .nba { return 60 }
            if choice == .stocks { return 300 }
        }
        return TimeInterval(refreshMinutes * 60)
    }
    private func dueAt(_ choice: RadioChannel, now: Date) -> Date {
        (lastAttempts[choice] ?? batches[choice]?.fetchedAt)?.addingTimeInterval(refreshInterval(for: choice)) ?? now
    }
    /// The controller checks once a minute while running; this is an approximate due time.
    func nextRefreshAt(now: Date = Date()) -> Date? {
        guard refreshMinutes > 0 else { return nil }
        return feedChannels.filter { !fetching.contains($0) }.map { max(now, dueAt($0, now: now)) }.min()
    }

    func choose(_ choice: RadioChannel) {
        guard channels.contains(choice) else { return }
        channel = choice
        refreshIfNeeded()
    }
    func cycleChannel() {
        let available = channels
        guard !available.isEmpty else { return }
        let index = available.firstIndex(of: channel) ?? -1
        choose(available[(index + 1) % available.count])
    }

    func step(_ direction: Int) {
        if channel == .codex { codex.step(direction); return }
        guard !items.isEmpty else { return }
        positions[channel] = (currentIndex + direction + items.count) % items.count
    }
    func refreshIfNeeded() {
        guard !setupOpen else { return }
        if channel == .codex { codex.refresh(); return }
        let stale = batches[channel].map { Date().timeIntervalSince($0.fetchedAt) > 900 } ?? true
        let recentAttempt = lastAttempts[channel].map { Date().timeIntervalSince($0) < 60 } ?? false
        if stale && !recentAttempt { refresh() }
    }
    func periodicRefresh(now: Date = Date()) {
        guard !setupOpen, refreshMinutes > 0 else { return }
        for choice in feedChannels {
            if dueAt(choice, now: now) <= now { refresh(choice) }
        }
    }
    func prepareEdition() { guard !setupOpen else { return }; for choice in feedChannels { refresh(choice) } }
    func refresh(_ target: RadioChannel? = nil) {
        guard !setupOpen else { return }
        let target = target ?? channel
        if target == .codex { codex.refresh(); return }
        guard !fetching.contains(target) else { return }
        let config = configuration
        let requestID = UUID()
        requestIDs[target] = requestID
        lastAttempts[target] = Date()
        fetching.insert(target)
        failures[target] = nil
        tasks[target] = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.requestIDs[target] == requestID {
                    self.fetching.remove(target)
                    self.tasks[target] = nil
                    self.requestIDs[target] = nil
                }
            }
            do {
                var batch = try await self.fetcher(target, config)
                guard !Task.isCancelled, config == self.configuration else { return }
                if target == .stocks {
                    let previous = self.batches[target]?.items ?? []
                    let merged = batch.items.map { item -> RadioItem in
                        guard let quote = item.stockQuote, quote.price == nil,
                              var saved = previous.first(where: { $0.id == item.id })?.stockQuote, saved.price != nil else { return item }
                        saved.isCached = true
                        return saved.item
                    }
                    batch = FeedBatch(items: merged, fetchedAt: batch.fetchedAt, warning: batch.warning)
                }
                let visibleItems = self.displayItems(self.batches[target], channel: target)
                let selectedIndex = min(self.positions[target] ?? 0, max(0, visibleItems.count - 1))
                let selectedID = visibleItems.isEmpty ? nil : visibleItems[selectedIndex].id
                self.batches[target] = batch
                if let selectedID, let index = self.displayItems(batch, channel: target).firstIndex(where: { $0.id == selectedID }) {
                    self.positions[target] = index
                } else { self.positions[target] = 0 }
                do { try self.cache.save(batch, channel: target, configuration: config); self.cacheWarning = nil }
                catch { self.cacheWarning = "Updated, but this edition could not be saved offline." }
                if target == .resets && self.resetAlertsActive {
                    let fresh = self.resetLedger.consume(batch.items)
                    self.defaults.set(try? JSONEncoder().encode(self.resetLedger), forKey: "resetAlertLedger")
                    // One banner per poll; all announcements remain readable in the station.
                    if let latest = fresh.first { self.onResetAnnouncement?(latest) }
                }
            } catch {
                guard !Task.isCancelled, config == self.configuration else { return }
                self.failures[target] = error.localizedDescription
            }
        }
    }
    func saveSources(query: String, feed: String) -> String? {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFeed = feed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty, cleanQuery.count <= 256 else { return "Enter a GitHub query between 1 and 256 characters." }
        if !cleanFeed.isEmpty {
            guard let url = URL(string: cleanFeed), url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return "Use a complete HTTPS address without a username or password." }
        }
        var next = configuration
        next.githubQuery = cleanQuery
        next.customFeedURL = cleanFeed
        return saveConfiguration(next)
    }

    func saveConfiguration(_ candidate: FeedConfiguration, refreshAfterSave: Bool = true) -> String? {
        var next = candidate
        do { next.stockSymbols = try StockSymbols.normalize(candidate.stockSymbols) }
        catch { return error.localizedDescription }
        next.enabledChannels = StationCatalog.presets.filter { candidate.enabledChannels.contains($0.rawValue) }.map(\.rawValue)
        next.aiSourceIDs = StationCatalog.aiSources.filter { candidate.aiSourceIDs.contains($0.id) }.map(\.id)
        next.researchTopics = StationCatalog.researchTopics.filter { candidate.researchTopics.contains($0.id) }.map(\.id)
        next.customFeedURL = next.customFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !next.customFeedURL.isEmpty {
            guard let url = URL(string: next.customFeedURL), url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return "Use a complete HTTPS address without a username or password." }
        }
        guard !next.aiSourceIDs.isEmpty else { return "Choose at least one AI source." }
        guard !next.researchTopics.isEmpty else { return "Choose at least one research topic." }
        guard next.customStations.count <= 12 else { return "You can add up to 12 custom stations." }
        var identifiers = Set<String>()
        for index in next.customStations.indices {
            var station = next.customStations[index]
            station.title = station.title.trimmingCharacters(in: .whitespacesAndNewlines)
            station.feedURLs = station.feedURLs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            station.webpageURLs = station.webpageURLs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            station.keywords = station.keywords.trimmingCharacters(in: .whitespacesAndNewlines)
            guard RadioChannel(rawValue: "custom:" + station.id) != nil, identifiers.insert(station.id).inserted else { return "This station could not be saved. Add it again." }
            guard !station.title.isEmpty, station.title.count <= 40 else { return "Use a station name between 1 and 40 characters." }
            guard (1...8).contains(station.feedURLs.count + station.webpageURLs.count) else { return "Add between 1 and 8 source addresses." }
            guard station.keywords.count <= 200 else { return "Keep keywords under 200 characters." }
            for address in station.feedURLs + station.webpageURLs {
                guard let url = URL(string: address), url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return "Use a complete HTTPS address without a username or password." }
            }
            next.customStations[index] = station
        }
        guard !next.enabledChannels.isEmpty || next.customStations.contains(where: \.enabled) || !next.customFeedURL.isEmpty else { return "Keep at least one station switched on." }
        guard next != configuration else { return nil }
        // Cancel old requests before replacing their configuration; their completion cannot publish mismatched data.
        for task in tasks.values { task.cancel() }
        tasks.removeAll(); fetching.removeAll(); requestIDs.removeAll()
        configuration = next
        defaults.set(try? JSONEncoder().encode(next), forKey: "stationConfiguration")
        defaults.set(next.githubQuery, forKey: "githubQuery")
        defaults.set(next.customFeedURL, forKey: "customFeedURL")
        batches.removeAll()
        for c in feedChannels { batches[c] = cache.load(channel: c, configuration: next) }
        failures.removeAll(); positions.removeAll(); lastAttempts.removeAll()
        if !channels.contains(channel) { channel = channels.first ?? .ai }
        if refreshAfterSave { refresh() }
        return nil
    }
    func openSource() {
        guard let url = item?.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        NSWorkspace.shared.open(url)
    }
}
