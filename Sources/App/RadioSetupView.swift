import SwiftUI
import AppKit

/// First tuning uses the same case, paper and hardware as the reading screen.
struct RadioSetupView: View {
    @ObservedObject var model: RadioModel
    @State private var draft: FeedConfiguration
    @State private var language: RadioLanguage
    @State private var step = 0
    @State private var researchExpanded = false
    @State private var validation: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: RadioModel) {
        self.model = model
        _draft = State(initialValue: model.configuration)
        _language = State(initialValue: model.language)
    }
    private func t(_ text: String) -> String { language.text(text) }
    private var title: String { ["Choose your topics", "Make it feel familiar", "Ready for your morning"][step] }
    private var validSelection: Bool {
        (!draft.enabledChannels.isEmpty || draft.customStations.contains(where: \.enabled) || !draft.customFeedURL.isEmpty)
        && (!draft.enabledChannels.contains("research") || !draft.researchTopics.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MoldedPlasticText(text: "CATECHO", size: 10, classic: model.isClassic, tracking: 2)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Capsule().fill(index == step ? RadioPlastic.sage : RadioPlastic.edge.opacity(0.4)).frame(width: index == step ? 20 : 5, height: 5)
                    }
                }.accessibilityHidden(true)
                Text("\(step + 1) / 3").font(.system(size: 10, design: .monospaced))
                    .accessibilityLabel(t("Setup step") + " \(step + 1) / 3")
            }.frame(height: 34).padding(.horizontal, 4)
                .overlay { WindowDragHandle(hint: t("Drag to move Catecho")) { model.onWindowDragFinished?() } }
            screen
            controls
        }
        .padding(.horizontal, 18).padding(.bottom, 4).padding(.top, 6)
        .frame(width: 350, height: 392)
        .background(RadioShell(classic: model.isClassic))
        .foregroundStyle(Color.radioInk)
        .environment(\.locale, language.locale)
        .preferredColorScheme(.light)
        .padding(12)
    }

    private var screen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t(title)).font(.system(size: 22, weight: .medium, design: .serif))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Color.radioInk.opacity(0.25)).frame(height: 0.6)
            if step == 0 && !validSelection {
                Text(t(draft.enabledChannels.contains("research") && draft.researchTopics.isEmpty ? "Choose at least one research topic." : "Keep at least one station switched on."))
                    .font(.system(size: 11, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if step == 0 { topics }
                    else if step == 1 { languages }
                    else { morning }
                    if let validation { Text(t(validation)).font(.system(size: 11, weight: .medium)).fixedSize(horizontal: false, vertical: true) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2)
            }.id(step)
        }
        .padding(.horizontal, 17).padding(.vertical, 12)
        .frame(width: 314, height: 264)
        .background {
            RoundedRectangle(cornerRadius: 17)
                .fill((model.isClassic ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.72, green: 0.75, blue: 0.67), .radioPaper, Color(red: 0.83, green: 0.84, blue: 0.77)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioPaper))
                    .shadow(.inner(color: .black.opacity(model.isClassic ? 0.25 : 0), radius: 4, x: 1, y: 3)))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.radioInk.opacity(0.5), lineWidth: 1))
        }
    }

    @ViewBuilder private var topics: some View {
        Text(t("A few good stories about the things you care about.")).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
        ForEach(StationCatalog.presets, id: \.rawValue) { channel in
            Toggle(t(channel.title), isOn: selection(channel.rawValue, list: $draft.enabledChannels))
                .toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic)).font(.system(size: 12, weight: .medium)).padding(.vertical, 3)
            if channel == .research && draft.enabledChannels.contains("research") {
                Button { researchExpanded.toggle() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("Research subjects")).font(.system(size: 11, weight: .medium))
                            Text(StationCatalog.researchTopics.filter { draft.researchTopics.contains($0.id) }.map { t($0.title) }.joined(separator: " · "))
                                .font(.system(size: 10)).lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: researchExpanded ? "chevron.up" : "chevron.down").font(.system(size: 10))
                    }.contentShape(Rectangle()).padding(.vertical, 3)
                }.buttonStyle(.plain).accessibilityLabel(t("Research subjects"))
                    .accessibilityValue(t(researchExpanded ? "Expanded" : "Collapsed"))
                if researchExpanded {
                    ForEach(StationCatalog.researchTopics) { subject in
                        Toggle(t(subject.title), isOn: selection(subject.id, list: $draft.researchTopics))
                            .toggleStyle(RadioSlideSwitchStyle(classic: model.isClassic)).font(.system(size: 11)).padding(.leading, 8)
                    }
                }
            }
        }
        Text(t("You can change these and add websites on the back of the radio.")).font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
    }

    private var languages: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(t("Choose the language on your radio.")).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            ForEach(RadioLanguage.allCases, id: \.rawValue) { choice in
                Button { language = choice } label: {
                    HStack {
                        Text(choice == .system ? t("System default") : choice.nativeName).font(.system(size: 12, weight: .medium))
                        Spacer()
                        ZStack {
                            Capsule().fill(RadioPlastic.edge.opacity(0.5)).frame(width: 31, height: 8)
                            if language == choice { RadioSliderThumb(classic: model.isClassic).frame(width: 25, height: 15) }
                        }.frame(width: 32, height: 20)
                    }.padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.radioCream.opacity(language == choice ? 0.8 : 0.25)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(RadioPlastic.edge.opacity(0.45), lineWidth: 0.6))
                }.buttonStyle(RadioHardwareButtonStyle())
                    .accessibilityAddTraits(language == choice ? .isSelected : [])
            }
            Text(t("Supported article translations stay on your Mac. Original text is always available.")).font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var morning: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                WaveSignal(active: false, compact: true).frame(width: 48, height: 36)
                Text(t("A small briefing, ready when you are.")).font(.system(size: 13, weight: .medium, design: .serif)).fixedSize(horizontal: false, vertical: true)
            }
            RadioLoginItemControl(classic: model.isClassic, language: language)
            Text(t("Catecho starts tucked at the edge and fetches your stations.")).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
            Text(t("Updates run while your Mac is awake and Catecho is open.")).font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controls: some View {
        HStack(spacing: 13) {
            SpeakerGrille(classic: model.isClassic)
            Spacer(minLength: 0)
            VStack(spacing: 7) {
                if step > 0 {
                    Button { move(to: step - 1) } label: { Label(t("Back"), systemImage: "chevron.left") }
                        .buttonStyle(RadioServiceButtonStyle(classic: model.isClassic))
                        .keyboardShortcut(.cancelAction)
                }
                Button(t(model.hasCompletedSetup ? "Keep current settings" : "Use defaults")) { model.skipSetup() }
                    .font(.system(size: 10)).buttonStyle(.plain).padding(.vertical, 5)
            }.frame(maxWidth: .infinity)
            Button {
                if step < 2 { move(to: step + 1) }
                else {
                    if draft.researchTopics.isEmpty { draft.researchTopics = model.configuration.researchTopics }
                    validation = model.finishSetup(configuration: draft, language: language)
                }
            } label: {
                VStack(spacing: 3) {
                    TuningDial(classic: model.isClassic, active: false, channelIndex: step)
                    Text(t(step == 2 ? "Start reading" : "Continue")).font(.system(size: 10, weight: .medium))
                }
            }.buttonStyle(RadioHardwareButtonStyle())
                .disabled(!validSelection).opacity(validSelection ? 1 : 0.45)
                .accessibilityLabel(t(step == 2 ? "Start reading" : "Continue"))
                .keyboardShortcut(.defaultAction)
        }.frame(height: 80).padding(.horizontal, 5)
    }
    private func move(to next: Int) {
        validation = nil
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { step = next }
    }
    private func selection(_ id: String, list: Binding<[String]>) -> Binding<Bool> {
        Binding(get: { list.wrappedValue.contains(id) }, set: { on in
            if on { if !list.wrappedValue.contains(id) { list.wrappedValue.append(id) } }
            else { list.wrappedValue.removeAll { $0 == id } }
        })
    }
}

struct RadioLoginItemControl: View {
    let classic: Bool
    let language: RadioLanguage
    @StateObject private var login = CommandLine.arguments.contains("--setup-preview")
        ? RadioLoginItem(readStatus: { .notFound }, register: {}, unregister: {}, openSettings: {})
        : RadioLoginItem()
    private func t(_ text: String) -> String { language.text(text) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(t("Start at login"), isOn: Binding(get: { login.isRequested }, set: { login.setEnabled($0) }))
                .toggleStyle(RadioSlideSwitchStyle(classic: classic)).font(.system(size: 12, weight: .medium))
                .disabled(!login.canChange)
            Text(t(statusText)).font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
            if let error = login.errorKey { Text(t(error)).font(.system(size: 10, weight: .medium)).fixedSize(horizontal: false, vertical: true) }
            if login.state == .approvalRequired || login.errorKey != nil {
                Button(t("Open Login Items")) { login.openSettings() }.buttonStyle(RadioServiceButtonStyle(classic: classic))
            }
        }
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
        // The radio is a nonactivating panel; returning from System Settings can
        // give its window focus without activating the application.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in login.refresh() }
    }
    private var statusText: String {
        if login.state == .unavailable { return "Start at login is unavailable on this Mac." }
        if !login.canChange { return "Move Catecho to Applications before enabling start at login." }
        switch login.state {
        case .off: return "Off — open Catecho whenever you like."
        case .on: return "On — Catecho will open when you log in."
        case .approvalRequired: return "Allow Catecho in macOS Login Items to finish enabling it."
        case .unavailable: return "Start at login is unavailable on this Mac."
        }
    }
}
