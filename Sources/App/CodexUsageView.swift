import SwiftUI

struct CodexUsageView: View {
    @ObservedObject var monitor: CodexMonitorModel
    let language: RadioLanguage
    let classic: Bool
    let visible: Bool
    let showSettings: () -> Void
    private func t(_ value: String) -> String { language.text(value) }

    var body: some View {
        if visible {
            TimelineView(.periodic(from: .now, by: 1)) { context in content(now: context.date) }
        } else { content(now: Date()) }
    }
    private func content(now: Date) -> some View {
        let snapshot = monitor.snapshot
        let events = monitor.scopedEvents
        let usage = monitor.usage(now: now)
        let unavailable = monitor.readingUnavailable
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Codex").font(.system(size: 20, weight: .medium, design: .serif))
                Spacer()
                Button { monitor.isChatPickerPresented = true } label: {
                    HStack(spacing: 4) {
                        Text(monitor.title(for: monitor.selectedSessionID, language: language)).lineLimit(1).truncationMode(.middle)
                        Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold))
                    }.font(.system(size: 10)).padding(.horizontal, 6).padding(.vertical, 5)
                        .frame(maxWidth: 138)
                        .background(Color.radioInk.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.radioInk.opacity(0.3), lineWidth: 0.6))
                }.buttonStyle(.plain)
                    .accessibilityLabel(t("Choose chat") + ", " + monitor.title(for: monitor.selectedSessionID, language: language))
                    .help(t("Choose chat") + " · " + t(monitor.simulated ? "PREVIEW" : "ON THIS MAC"))
                    .popover(isPresented: $monitor.isChatPickerPresented) { CodexChatPicker(monitor: monitor, language: language, classic: classic) }
                Button { monitor.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10)).frame(width: 22, height: 22)
                }.buttonStyle(.plain).help(t("Read local activity")).accessibilityLabel(t("Read local activity"))
            }
            Rectangle().fill(Color.radioInk.opacity(0.3)).frame(height: 0.6).padding(.top, 5)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(monitor.reading(now: now)).font(.system(size: 30, weight: .medium, design: .monospaced)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                Text(t(monitor.window == .second ? "tokens / sec" : "tokens")).font(.system(size: 10))
                Spacer(minLength: 0)
            }.padding(.top, 7)
                .help(t("Recorded updates arrive in batches. This is local token activity, not account allowance or exact generation speed."))
            Text(t(monitor.window.detail))
                .font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8).opacity(0.75)
                .help(t("Lifetime includes available local records. Deleted or unrecorded usage cannot be recovered."))
            if unavailable {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t(stateTitle(snapshot))).font(.system(size: 12, weight: .medium))
                    if snapshot?.isIndexing == true || snapshot == nil {
                        Text(t("Reading local records…")).font(.system(size: 10))
                    } else {
                        Button(t("Choose Codex folder"), action: showSettings).buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).underline()
                    }
                }.frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            } else {
                activityChart(events: events, now: now)
                    .padding(.top, 9)
                HStack {
                    Text(t("IN") + " " + compact(usage.input))
                    Spacer()
                    Text(t("OUT") + " " + compact(usage.output))
                }.font(.system(size: 9, design: .monospaced)).padding(.top, 3)
                    .help(t("Cached input is part of input; reasoning is part of output.") + "\n" + t("Cached input") + ": \(usage.cachedInput.formatted()) · " + t("Reasoning") + ": \(usage.reasoning.formatted())")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(t("Input") + " \(usage.input), " + t("Output") + " \(usage.output), " + t("Cached input") + " \(usage.cachedInput), " + t("Reasoning") + " \(usage.reasoning). " + t("Cached input is part of input; reasoning is part of output."))
            }
            Spacer(minLength: 2)
            RadioDetentPicker(title: t("Time view"), selection: $monitor.window, options: CodexUsageWindow.allCases.map { ($0, t($0.label)) }, classic: classic)
            HStack(spacing: 4) {
                Circle().fill(Color.radioInk.opacity(0.65)).frame(width: 4, height: 4)
                if let snapshot, snapshot.isIndexing {
                    Text(t("INDEXING") + " \(snapshot.filesScanned)/\(snapshot.filesTotal)")
                } else if let snapshot, snapshot.issue != nil || snapshot.warning != nil {
                    Button(t(snapshot.issue != nil ? "SAVED / UNAVAILABLE" : "PARTIAL HISTORY"), action: showSettings)
                        .buttonStyle(.plain).help(t("Some local records are unavailable. Counts may be incomplete."))
                } else if let date = monitor.scopedLastRecordedAt {
                    Text(t("LAST RECORD")); Text(date, style: .relative)
                } else { Text(t("NO RECORDED ACTIVITY")) }
                Spacer(minLength: 0)
                if let snapshot, (snapshot.issue != nil || snapshot.warning != nil), let date = monitor.scopedLastRecordedAt {
                    Text(date, format: .dateTime.hour().minute().second()).help(t("LAST RECORD"))
                }
            }.font(.system(size: 8, design: .monospaced)).lineLimit(1).padding(.top, 7)
        }
    }
    private func compact(_ count: Int64) -> String { count.formatted(.number.notation(.compactName)) }
    private func stateTitle(_ snapshot: CodexUsageSnapshot?) -> String {
        guard let snapshot else { return "Finding local activity" }
        if monitor.window == .lifetime && snapshot.lifetimeSessions == nil { return "Lifetime total unavailable" }
        if snapshot.isIndexing { return "Indexing local activity" }
        switch snapshot.issue {
        case .missingFolder: return "Codex folder not found"
        case .unreadable: return "Local records cannot be read"
        case .noLogs: return "No local session files yet"
        case nil: return "No recorded activity yet"
        }
    }
    private func activityChart(events: [CodexUsageEvent], now: Date) -> some View {
        let bins = monitor.window.bins(events, now: now)
        let peak = bins.max() ?? 0
        let maximum = max(1, peak)
        let range = monitor.window == .lifetime ? "Recent activity · 24h" : monitor.window == .second ? "Last 60 seconds" : monitor.window == .minute ? "Last 60 minutes" : "Last 24 hours"
        return VStack(spacing: 3) {
            Canvas { context, size in
                let slot = size.width / Double(bins.count)
                for (index, count) in bins.enumerated() where count > 0 {
                    let height = max(1, Double(count) / Double(maximum) * (size.height - 1))
                    let rect = CGRect(x: Double(index) * slot, y: size.height - height, width: max(1, slot - 1.5), height: height)
                    context.fill(Path(rect), with: .color(.radioInk.opacity(0.7)))
                }
                context.fill(Path(CGRect(x: 0, y: size.height - 0.5, width: size.width, height: 0.5)), with: .color(.radioInk.opacity(0.3)))
            }.frame(height: 36)
            HStack { Text(t(range)); Spacer(); Text(t("Now")) }.font(.system(size: 8, design: .monospaced)).opacity(0.7)
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(t(range) + ": \(bins.reduce(0, CodexUsageWindow.add).formatted()) " + t("tokens") + ". " + t("Recorded bursts; tallest bar") + ": \(peak.formatted()).")
    }
}

struct CodexMonitorSettings: View {
    @ObservedObject var monitor: CodexMonitorModel
    let language: RadioLanguage
    let classic: Bool
    private func t(_ value: String) -> String { language.text(value) }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            MoldedPlasticText(text: t("CODEX · LOCAL ACTIVITY"), size: 10, classic: classic, tracking: 1)
            Text(t("All Codex sessions on this Mac")).font(.system(size: 11, weight: .medium))
            Toggle(t("Token preview beside antenna"), isOn: $monitor.showEdgePreview)
                .font(.system(size: 11)).toggleStyle(RadioSlideSwitchStyle(classic: classic))
            Text(t("Choose All chats or one chat on the Codex screen. The antenna preview follows that choice."))
                .font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
            Text(t("Lifetime includes available local records. Deleted or unrecorded usage cannot be recovered."))
                .font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
            Text(monitor.rootDirectory.path).font(.system(size: 9, design: .monospaced)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(t("Choose folder…")) { monitor.chooseFolder(language: language) }
                Button(t("Use default")) { monitor.useDefaultFolder() }
            }.buttonStyle(RadioServiceButtonStyle(classic: classic))
            Text(t("Enable Codex in Stations to monitor local activity. Only numeric usage is saved on this Mac; nothing is uploaded."))
                .font(.system(size: 10)).foregroundStyle(Color.radioInk.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            Text(t("Recorded updates arrive in batches. This is local token activity, not account allowance or exact generation speed."))
                .font(.system(size: 10)).foregroundStyle(Color.radioInk.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            if let snapshot = monitor.snapshot, snapshot.issue != nil || snapshot.warning != nil {
                Text(t("Some local records are unavailable. Counts may be incomplete.")).font(.system(size: 10, weight: .medium))
                if let detail = snapshot.warning { Text(t(detail)).font(.system(size: 9)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }
}
