import SwiftUI
import AppKit

private enum Workshop {
    static let ink = Color.radioInk
    static let brass = RadioPlastic.sage
}

struct RadioHardwareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.92 : 1).brightness(configuration.isPressed ? -0.07 : 0)
    }
}

struct RadioSettings: View {
    @ObservedObject var model: RadioModel
    private let initialTab: Int
    private let returnRequest: Int
    private let onReturnRejected: () -> Void
    @State private var draft = FeedConfiguration()
    @State private var stockInput = ""
    @State private var validation: String?
    @State private var editingID: String?
    @State private var customName = ""
    @State private var customFeeds = ""
    @State private var customKeywords = ""
    @State private var editorOpen = false
    @State private var batteryOpen = false
    @StateObject private var feedDiscovery = FeedDiscoveryModel()
    @State private var discoveryRetry = 0

    init(model: RadioModel, initialTab: Int = 0, initialBatteryOpen: Bool = false, returnRequest: Int = 0, onReturnRejected: @escaping () -> Void = {}) {
        self.model = model
        self.initialTab = initialTab
        self.returnRequest = returnRequest
        self.onReturnRejected = onReturnRejected
        _batteryOpen = State(initialValue: initialBatteryOpen)
        _draft = State(initialValue: model.configuration)
        _stockInput = State(initialValue: model.configuration.stockSymbols.joined(separator: ", "))
    }

    private var dirty: Bool { draft != model.configuration || stockInput != model.configuration.stockSymbols.joined(separator: ", ") || editorOpen }
    private var hasEditorText: Bool { !customName.isEmpty || !customFeeds.isEmpty || !customKeywords.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        stations.id(0)
                        Divider().padding(.vertical, 6)
                        markets.id(3)
                        Divider().padding(.vertical, 6)
                        sources.id(1)
                        Divider().padding(.vertical, 6)
                        radio.id(2)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(RadioControlRecess(classic: model.isClassic))
                .onAppear { if initialTab != 0 { proxy.scrollTo(initialTab, anchor: .top) } }
                .onChange(of: model.settingsOpen) { _, open in if open && model.channel == .codex { proxy.scrollTo(2, anchor: .top) } }
            }.padding(.horizontal, 18)
            RadioBatteryCompartment(model: model, isOpen: $batteryOpen)
                .padding(.horizontal, 20).padding(.top, 10)
            if let validation {
                Text(model.t(validation)).font(.system(size: 10)).foregroundStyle(Color(red: 0.43, green: 0.30, blue: 0.17))
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 5)
            }
            footer
        }
        .frame(width: 350, height: 392)
        .background(RadioRearHousing(classic: model.isClassic))
        .foregroundStyle(Workshop.ink)
        .environment(\.colorScheme, .light)
        .tint(Workshop.brass)
        .buttonStyle(RadioServiceButtonStyle(classic: model.isClassic))
        .onAppear { draft = model.configuration; stockInput = draft.stockSymbols.joined(separator: ", ") }
        .onChange(of: returnRequest) { _, _ in
            if !save(close: true) { onReturnRejected() }
        }
        .onChange(of: model.settingsOpen) { _, open in
            draft = model.configuration; validation = nil; resetEditor()
            stockInput = draft.stockSymbols.joined(separator: ", ")
            if !open { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            MoldedPlasticText(text: "CATECHO", size: 13, classic: model.isClassic, tracking: 1.2)
            Spacer()
            Text(model.t("SETTINGS")).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1).opacity(0.7)
        }.padding(.horizontal, 23).frame(height: 44)
    }
    private var footer: some View {
        HStack(spacing: 7) {
            HStack(spacing: 4) {
                Circle().fill(dirty ? Workshop.brass : RadioPlastic.edge.opacity(0.5)).frame(width: 4, height: 4)
                Text(model.t(dirty ? "Unsaved changes" : "LOCAL RECEPTION")).font(.system(size: 8, design: .monospaced))
            }.opacity(0.85)
            Spacer(minLength: 2)
            RadioFlipButton(classic: model.isClassic, title: model.t("Flip to front")) { _ = save(close: true) }
                .help(model.t("Save and flip to front")).accessibilityLabel(model.t("Save and flip to front"))
        }.padding(.horizontal, 21).frame(height: 40)
    }
    private func label(_ text: String) -> some View {
        MoldedPlasticText(text: model.t(text), size: 11, classic: model.isClassic, tracking: 0.7)
            .padding(.vertical, 2)
            .accessibilityAddTraits(.isHeader)
    }
    private func note(_ text: String) -> some View {
        Text(model.t(text)).font(.system(size: 10)).lineSpacing(3).opacity(0.74).fixedSize(horizontal: false, vertical: true)
    }
    private func selection(_ value: String, list: Binding<[String]>) -> Binding<Bool> {
        Binding(get: { list.wrappedValue.contains(value) }, set: { enabled in
            if enabled { if !list.wrappedValue.contains(value) { list.wrappedValue.append(value) } }
            else { list.wrappedValue.removeAll { $0 == value } }
            validation = nil
        })
    }

    @ViewBuilder private var stations: some View {
        label("PRESET FREQUENCIES")
        note("Switch on the subjects you want on your dial.")
        ForEach(StationCatalog.presets, id: \.rawValue) { channel in
            Toggle(isOn: selection(channel.rawValue, list: $draft.enabledChannels)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.t(channel.title)).font(.system(size: 12, weight: .medium))
                    Text(model.t(channel.subtitle)).font(.system(size: 9)).opacity(0.65).lineLimit(2)
                }
            }.toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic))
        }
        Divider().overlay(Workshop.brass.opacity(0.2))
        label("YOUR OWN FREQUENCIES")
        ForEach($draft.customStations) { $station in
            HStack {
                Toggle(station.title, isOn: $station.enabled).toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic)).font(.system(size: 12))
                Button { edit(station) } label: { Image(systemName: "pencil") }.help(model.t("Edit station")).accessibilityLabel(model.t("Edit station") + ": " + station.title)
                Button { draft.customStations.removeAll { $0.id == station.id } } label: { Image(systemName: "minus.circle") }.help(model.t("Remove station")).accessibilityLabel(model.t("Remove station") + ": " + station.title)
            }.buttonStyle(.plain)
        }
        if !draft.customFeedURL.isEmpty {
            Text(model.t("Your Feed")).font(.system(size: 12, weight: .medium))
            TextField(model.t("Your own RSS or Atom feed"), text: $draft.customFeedURL).textFieldStyle(RadioFieldStyle(classic: model.isClassic)).font(.system(size: 11))
            note("Clear this address to remove your old single-feed station.")
        }
        if editorOpen { customEditor }
        else {
            Button { batteryOpen = false; editorOpen = true; validation = nil } label: { Label(model.t("Add custom station"), systemImage: "plus") }.controlSize(.small)
        }
    }
    @ViewBuilder private var customEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(model.t("Station name"), text: $customName)
            Text(model.t("Website links · one per line")).font(.system(size: 10))
            TextEditor(text: $customFeeds).scrollContentBackground(.hidden).font(.system(size: 11)).frame(height: 58).padding(3).background(RadioPlastic.highlight, in: RoundedRectangle(cornerRadius: 4))
                .accessibilityLabel(model.t("Website links · one per line"))
            note("Paste a website link. We’ll find a feed or read its article list.")
            discoveredFeeds
            TextField(model.t("Keywords · optional, comma separated"), text: $customKeywords)
                .help(model.t("Keywords are optional. Leave blank for all stories, or match any keyword in the title or excerpt."))
            HStack {
                Button(model.t(editingID == nil ? "Add station" : "Update station")) { storeEditor() }.controlSize(.small)
                    .disabled(feedDiscovery.selectedURLs(for: customFeeds) == nil)
                Button(model.t("Cancel")) { resetEditor() }.controlSize(.small)
            }
        }.textFieldStyle(RadioFieldStyle(classic: model.isClassic)).font(.system(size: 11)).padding(10).background(RadioPlastic.recess.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
            .task(id: "\(discoveryRetry):\(customFeeds)") {
                let known = draft.customStations.first { $0.id == editingID }
                let input = customFeeds
                await feedDiscovery.search(input, knownURLs: known?.feedURLs ?? [], knownWebpageURLs: known?.webpageURLs ?? [])
                if !Task.isCancelled, editorOpen, customFeeds == input, customName.isEmpty, editingID == nil,
                   let first = feedDiscovery.groups.first?.feeds.first {
                    customName = String(first.title.prefix(40))
                }
            }
    }
    @ViewBuilder private var discoveredFeeds: some View {
        if feedDiscovery.isSearching {
            HStack(spacing: 5) {
                WaveSignal(active: true, compact: true).frame(width: 24, height: 18)
                Text(model.t("Finding updates…")).font(.system(size: 10, weight: .medium))
            }.accessibilityElement(children: .combine)
        }
        ForEach(feedDiscovery.groups) { group in
            VStack(alignment: .leading, spacing: 5) {
                if feedDiscovery.groups.count > 1 {
                    Text((try? FeedDiscovery.websiteURL(group.input).host) ?? group.input)
                        .font(.system(size: 9, weight: .medium)).lineLimit(1)
                }
                if let error = group.error {
                    note(error)
                } else {
                    Text(model.t(group.feeds.first?.kind == .webpage ? "Read from website" : (group.feeds.count == 1 ? "Feed found" : "Choose feeds")))
                        .font(.system(size: 10, weight: .semibold))
                    if group.feeds.first?.kind == .webpage { note("No feed needed. Reads public article links; dates and summaries depend on the website.") }
                    ForEach(group.feeds) { feed in
                        Toggle(isOn: Binding(get: { feedDiscovery.selected.contains(feed.id) }, set: { _ in feedDiscovery.toggle(feed) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.title).font(.system(size: 11, weight: .medium)).lineLimit(2)
                                Text(feed.url.host ?? "").font(.system(size: 9)).opacity(0.7)
                            }
                        }.toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic))
                            .help(feed.url.absoluteString)
                    }
                }
            }
        }
        if let error = feedDiscovery.error { note(error) }
        if feedDiscovery.selected.count > 8 { note("Choose up to 8 sources for this station.") }
        if !feedDiscovery.isSearching && (feedDiscovery.error != nil || feedDiscovery.groups.contains { $0.error != nil }) {
            Button(model.t("Try finding again")) { discoveryRetry += 1; validation = nil }
        }
    }
    @ViewBuilder private var sources: some View {
        label("GITHUB TREND WINDOW")
        RadioDetentPicker(title: model.t("Trend period"), selection: $draft.githubPeriod, options: GitHubPeriod.allCases.map { ($0, model.t($0.title)) }, classic: model.isClassic)
        note("GitHub Trending order, with stars gained in the selected period.")
        Divider()
        label("AI NEWS SOURCES")
        ForEach(StationCatalog.aiSources) { source in
            Toggle(isOn: selection(source.id, list: $draft.aiSourceIDs)) {
                HStack {
                    Text(source.title).font(.system(size: 11))
                    Spacer(minLength: 2)
                    Text(model.t(source.perspective)).font(.system(size: 8)).opacity(0.6)
                }
            }.toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic))
        }
        Divider()
        label("RESEARCH SUBJECTS")
        note("Choose several subjects. arXiv papers are preprints; they may not be peer reviewed.")
        ForEach(StationCatalog.researchTopics) { topic in
            Toggle(model.t(topic.title), isOn: selection(topic.id, list: $draft.researchTopics)).toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic)).font(.system(size: 11))
        }
        Divider()
        label("PUBLIC SCOREBOARD")
        note("NBA uses ESPN’s public scoreboard. Availability and update speed can vary. The saved edition remains if reception fails.")
        label("OTHER STATION SOURCES")
        ForEach(StationCatalog.presets.filter { ![RadioChannel.ai, .github, .research, .nba, .codex].contains($0) }, id: \.rawValue) { channel in
            VStack(alignment: .leading, spacing: 3) {
                Text(model.t(channel.title)).font(.system(size: 11, weight: .medium))
                Text(StationCatalog.sources(for: channel).map(\.title).joined(separator: " · ")).font(.system(size: 10)).opacity(0.65)
            }
        }
    }
    @ViewBuilder private var markets: some View {
        label("US STOCK WATCHLIST")
        TextField("AAPL, MSFT", text: $stockInput)
            .textFieldStyle(RadioFieldStyle(classic: model.isClassic)).font(.system(size: 11, design: .monospaced))
            .accessibilityLabel(model.t("US stock tickers"))
        note("Up to 20 US tickers, separated by commas. Every quote stays on the dial, followed by your chosen number of headlines.")
        note("Yahoo Finance regular-session prices may be delayed. Each quote shows its source timestamp.")
        Divider()
        label("TIBO RESET ALERTS")
        Toggle(model.t("Alert for new reset announcements"), isOn: $draft.resetAlerts)
            .toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic)).font(.system(size: 11))
        note("Enable Tibo Resets on your dial. New announcements are checked about every five minutes while Catecho is running. The first check is quiet.")
        note("Community tracker of @thsottiaux on X. An announcement does not confirm a reset on your account.")
        Link("Codex Resets", destination: ResetAnnouncements.attribution).font(.system(size: 10))
        if model.resetAlertsActive {
            note(model.resetNotificationStatus)
            Button(model.t("Notification settings")) { model.onNotificationSettings?() }
                .controlSize(.small)
        }
    }
    @ViewBuilder private var radio: some View {
        CodexMonitorSettings(monitor: model.codex, language: model.language, classic: model.isClassic)
        Divider()
        RadioLoginItemControl(classic: model.isClassic, language: model.language)
        Divider()
        label("DISPLAY & RECEPTION")
        RadioDetentPicker(title: model.t("Appearance"), selection: $model.appearance, options: [("Classic", model.t("Classic")), ("Flat", model.t("Flat"))], classic: model.isClassic)
        RadioDetentPicker(title: model.t("Screen edge"), selection: $model.edge, options: [("Left", model.t("Left")), ("Right", model.t("Right"))], classic: model.isClassic)
        Toggle(model.t("Keep open while I work"), isOn: $model.pinned).toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic)).font(.system(size: 11))
        RadioDetentPicker(title: model.t("Stories per channel"), selection: $model.quantity, options: [3, 5, 8].map { ($0, String($0)) }, classic: model.isClassic)
        RadioDetentPicker(title: model.t("Refresh interval"), selection: $model.refreshMinutes, options: [(0, model.t("Manual")), (15, model.t("15 min")), (60, model.t("Hourly"))], classic: model.isClassic)
        note("NBA checks every minute while open. Stocks check every five minutes while open; enabled reset alerts check every five minutes. Manual pauses all periodic checks.")
        Divider()
        label("LANGUAGE")
        RadioDetentPicker(title: model.t("Language"), selection: $model.language, options: RadioLanguage.allCases.map { ($0, $0 == .system ? model.t("System default") : $0.nativeName) }, classic: model.isClassic)
        Toggle(model.t("Translate articles on this Mac"), isOn: $model.translateArticles).toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic)).font(.system(size: 11))
        note("Uses Apple’s on-device translation on macOS 15+. The first translation may require a language download. Originals stay available.")
        note("Sports scores and team names stay in their original form.")
        if let status = model.statusMessage {
            Divider(); label("RECEPTION STATUS")
            Text(status).font(.system(size: 11)).textSelection(.enabled)
            Button(model.t("Try fetching again")) { model.refresh() }.controlSize(.small)
        }
        note("Source excerpts, stored on this Mac. No cloud account or AI subscription.")
    }

    private func edit(_ station: CustomStation) {
        batteryOpen = false; editingID = station.id; customName = station.title; customFeeds = (station.feedURLs + station.webpageURLs).joined(separator: "\n"); customKeywords = station.keywords; editorOpen = true; validation = nil
    }
    private func resetEditor() { feedDiscovery.cancel(); validation = nil; editingID = nil; customName = ""; customFeeds = ""; customKeywords = ""; editorOpen = false }
    private func storeEditor() {
        guard !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { validation = "Use a station name between 1 and 40 characters."; return }
        guard let sources = feedDiscovery.selectedSources(for: customFeeds) else {
            validation = feedDiscovery.isSearching ? "Please wait while Catecho finds updates." : "Choose a found source for each website, or change the link."
            return
        }
        let station = CustomStation(id: editingID ?? UUID().uuidString, title: customName, feedURLs: sources.filter { $0.kind == .feed }.map { $0.url.absoluteString }, webpageURLs: sources.filter { $0.kind == .webpage }.map { $0.url.absoluteString }, keywords: customKeywords, enabled: editingID.flatMap { id in draft.customStations.first { $0.id == id }?.enabled } ?? true)
        if let index = draft.customStations.firstIndex(where: { $0.id == station.id }) { draft.customStations[index] = station }
        else { draft.customStations.append(station) }
        resetEditor(); validation = nil
    }
    @discardableResult private func save(close: Bool) -> Bool {
        if editorOpen && hasEditorText { storeEditor(); if editorOpen { return false } }
        do { draft.stockSymbols = try StockSymbols.parse(stockInput) }
        catch { validation = error.localizedDescription; return false }
        validation = model.saveConfiguration(draft)
        if validation == nil {
            draft = model.configuration
            stockInput = draft.stockSymbols.joined(separator: ", ")
            validation = "Settings saved."
            if close { model.settingsOpen = false }
            return true
        }
        return false
    }
}

