import SwiftUI

struct RadioView: View {
    @ObservedObject var model: RadioModel
    var previewLabel: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle = 0.0
    @State private var dragStart: Double?
    @State private var pendingAngle: Double?
    @State private var settling = false
    @State private var returnRequest = 0
    private var active: Bool { model.isFetching && model.isExpanded && !model.settingsOpen }
    private var interacting: Bool { settling || dragStart != nil }

    var body: some View {
        Group {
            if model.setupOpen { RadioSetupView(model: model) }
            else { radioBody }
        }.onChange(of: model.setupOpen) { _, _ in
            angle = 0; dragStart = nil; pendingAngle = nil; settling = false
        }
    }

    private var radioBody: some View {
        RadioTurnStage(angle: angle, backShown: model.settingsOpen, interacting: interacting, classic: model.isClassic, reduceMotion: reduceMotion) {
            front
        } back: {
            RadioSettings(model: model, initialTab: model.channel == .codex ? 2 : 0, returnRequest: returnRequest, onReturnRejected: { settle(to: 180) })
        }
        .overlay {
            HStack(spacing: 0) {
                turnGrip
                Spacer(minLength: 0)
                turnGrip
            }
        }
        .preferredColorScheme(.light)
        .environment(\.locale, model.language.locale)
        .padding(12)
        .onAppear { angle = model.settingsOpen ? 180 : 0 }
        .onChange(of: model.settingsOpen) { _, back in
            let target = pendingAngle ?? (back ? -180 : 0)
            pendingAngle = nil
            settle(to: target)
        }
        .onChange(of: reduceMotion) { _, _ in
            dragStart = nil
            angle = model.settingsOpen ? 180 : 0
        }
        .onExitCommand { if model.settingsOpen { model.settingsOpen = false } else { model.onTuck?() } }
    }

    private var turnGrip: some View {
        RadioTurnGrip(classic: model.isClassic, label: model.t(model.settingsOpen ? "Flip to front" : "Flip to back"), hint: model.t("Drag sideways to turn the radio"), action: {
            guard !interacting else { return }
            if model.settingsOpen { returnRequest += 1 }
            else { model.settingsOpen = true }
        }, changed: { translation in
            guard !settling else { return }
            if dragStart == nil { dragStart = model.settingsOpen ? 180 : 0 }
            if !reduceMotion { angle = (dragStart ?? 0) + RadioTurn.rotation(for: translation) }
        }, ended: { translation in
            guard let start = dragStart, !settling else { return }
            dragStart = nil
            let target = RadioTurn.destination(from: start, translation: translation, allowed: true)
            guard target != start else { settle(to: start); return }
            pendingAngle = target
            if model.settingsOpen { returnRequest += 1 }
            else { model.settingsOpen = true }
        })
        .disabled(settling)
        .opacity(interacting ? 0 : 1)
    }

    private func settle(to target: Double) {
        dragStart = nil
        pendingAngle = nil
        guard !reduceMotion else { angle = model.settingsOpen ? 180 : 0; settling = false; return }
        settling = true
        withAnimation(.easeInOut(duration: 0.58), completionCriteria: .removed) {
            angle = target
        } completion: {
            // Equivalent orientations are normalized without animating a second turn.
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { angle = model.settingsOpen ? 180 : 0; settling = false }
        }
    }
    private var front: some View {
        VStack(spacing: 0) {
            HStack {
                RadioSettingsButton(classic: model.isClassic, label: model.t("Radio settings")) { model.settingsOpen = true }
                Spacer()
                Text("CATECHO").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(2).opacity(0.6)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .overlay { if previewLabel == nil { WindowDragHandle(hint: model.t("Drag to move Catecho")) { model.onWindowDragFinished?() } } }
                    .help(model.t("Drag here to move the radio"))
                Spacer()
                Button { model.onTuck?() } label: {
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).frame(width: 26, height: 18)
                        .background(Color.radioCream.shadow(.inner(color: .black.opacity(model.isClassic ? 0.25 : 0), radius: 2, x: 0, y: 1)), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.radioInk.opacity(0.45), lineWidth: 0.8))
                }.buttonStyle(RadioHardwareButtonStyle())
                    .help(model.t("Tuck at screen edge · Escape")).accessibilityLabel(model.t("Tuck at screen edge"))
            }
            .buttonStyle(.plain).frame(height: 34).padding(.horizontal, 4)
            screen
            HStack(alignment: .center, spacing: 16) {
                SpeakerGrille(classic: model.isClassic)
                Spacer(minLength: 0)
                RadioRoundButton(icon: "backward.end.fill", label: model.t(model.channel == .codex ? "Previous time view" : "Previous story"), classic: model.isClassic, disabled: model.channel != .codex && model.items.count < 2) { model.step(-1) }
                RadioRoundButton(icon: "forward.end.fill", label: model.t(model.channel == .codex ? "Next time view" : "Next story"), classic: model.isClassic, disabled: model.channel != .codex && model.items.count < 2) { model.step(1) }
                Spacer(minLength: 0)
                Button { model.cycleChannel() } label: {
                    VStack(spacing: 4) {
                        TuningDial(classic: model.isClassic, active: active, channelIndex: model.channels.firstIndex(of: model.channel) ?? 0)
                        Text(model.t("CHANNEL")).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
                    }
                }
                .buttonStyle(.plain).help(model.t("Next channel")).accessibilityLabel(model.t("Next channel") + ", " + model.channelTitle)
            }.frame(height: 80).padding(.horizontal, 5)
        }
        .padding(.horizontal, 18).padding(.bottom, 4).padding(.top, 6)
        .frame(width: 350, height: 392)
        .background(RadioShell(classic: model.isClassic))
        .foregroundStyle(Color.radioInk)
    }

    private var screen: some View {
        Group {
            if model.channel == .codex {
                CodexUsageView(monitor: model.codex, language: model.language, classic: model.isClassic, visible: model.isExpanded && !model.settingsOpen, showSettings: { model.settingsOpen = true })
            } else { editionScreen }
        }
        .padding(.horizontal, 17).padding(.vertical, 12)
        .frame(width: 314, height: 264)
        .background {
            RoundedRectangle(cornerRadius: 17)
                .fill((model.isClassic ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.72, green: 0.75, blue: 0.67), .radioPaper, Color(red: 0.83, green: 0.84, blue: 0.77)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioPaper)).shadow(.inner(color: .black.opacity(model.isClassic ? 0.25 : 0), radius: 4, x: 1, y: 3)))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.radioInk.opacity(model.isClassic ? 0.4 : 0.95), lineWidth: 1))
        }
    }

    private var editionScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(previewLabel ?? model.t("YOUR DAILY FREQUENCY")).font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(1.5)
                Spacer()
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .medium)).frame(width: 22, height: 22)
                }.buttonStyle(.plain).disabled(model.isFetching).help(model.t("Fetch latest information")).accessibilityLabel(model.t("Refresh channel"))
            }.frame(height: 20)
            HStack(alignment: .firstTextBaseline) {
                Text(model.channelTitle).font(.system(size: 25, weight: .medium, design: .serif)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                if !model.items.isEmpty { Text(String(format: "%02d / %02d", model.currentIndex + 1, model.items.count)).font(.system(size: 9, design: .monospaced)).opacity(0.65) }
            }.padding(.top, 3).padding(.bottom, 9)
            Rectangle().fill(Color.radioInk.opacity(0.3)).frame(height: 0.6)
            if let story = model.item {
                storyContent(story)
            } else {
                emptyContent
            }
            Spacer(minLength: 0)
            Rectangle().fill(Color.radioInk.opacity(0.24)).frame(height: 0.6)
            VStack(alignment: .leading, spacing: 0) {
                statusLine
            }.padding(.top, 7)
        }
    }

    @ViewBuilder private func storyContent(_ story: RadioItem) -> some View {
        if #available(macOS 15, *), model.translateArticles, previewLabel == nil, model.channel != .nba {
            let request = ArticleTranslationRequest(item: story, language: model.language.resolved(), repository: model.channel == .github)
            NativeArticleContent(model: model, request: request).id(request.key)
        } else {
            RadioStoryContent(model: model, story: story)
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 7) {
            WaveSignal(active: active).frame(width: 95, height: 60)
            Text(model.t(model.isFetching ? "Finding your signal" : (model.batches[model.channel] != nil ? "No matching stories" : "A quiet moment")))
                .font(.system(size: 19, weight: .medium, design: .serif))
            Text(model.t(model.isFetching ? "Tuning in to the latest edition…" : (model.batches[model.channel] != nil ? "No new items from these sources. Try another topic or keyword." : "Fetch an edition when you’re ready.")))
                .font(.system(size: 11)).opacity(0.7)
            if !model.isFetching {
                Button(model.t("Try again")) { model.refresh() }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).padding(.top, 3)
            }
        }.frame(maxWidth: .infinity).padding(.top, 8)
    }

    @ViewBuilder private var statusLine: some View {
        if model.isFetching {
            HStack(spacing: 4) {
                WaveSignal(active: active, compact: true).frame(width: 23, height: 17)
                Text(model.t(model.item == nil ? "TUNING IN" : "UPDATING · LAST EDITION SHOWN"))
                Spacer()
            }.font(.system(size: 8, weight: .medium, design: .monospaced)).accessibilityLabel(model.t("Fetching current information"))
            cachedFreshness
        } else if let message = model.statusMessage {
            Button { model.settingsOpen = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle")
                    Text(model.t(model.failures[model.channel] != nil ? (model.item == nil ? "Couldn’t fetch · details" : "Saved edition · details") : (model.cacheWarning != nil ? "Couldn’t save offline · details" : "Some sources unavailable · details"))).lineLimit(1)
                    Spacer(minLength: 0)
                }
            }.buttonStyle(.plain)
            .font(.system(size: 9)).help(message)
            .accessibilityElement(children: .ignore).accessibilityLabel(message)
            cachedFreshness
        } else if let date = model.batches[model.channel]?.fetchedAt {
            HStack(spacing: 4) {
                Circle().fill(Color.radioInk.opacity(0.6)).frame(width: 4, height: 4)
                Text(model.t(model.isStale ? "SAVED" : "UPDATED"))
                if model.channel == .nba { Text(date, format: .dateTime.hour().minute()) }
                else { Text(date, style: .relative) }
                Spacer(minLength: 0)
                Text(model.t(model.channel == .github ? "RECENT STARS" : (model.channel == .nba ? "PUBLIC SCOREBOARD" : "SOURCE EXCERPTS"))).font(.system(size: 7))
            }.font(.system(size: 8, design: .monospaced)).opacity(0.75)
        } else {
            Text(model.t("A LITTLE INFORMATION. A LITTLE SPACE.")).font(.system(size: 7, design: .monospaced)).tracking(0.5).opacity(0.65)
        }
    }

    @ViewBuilder private var cachedFreshness: some View {
        if let date = model.batches[model.channel]?.fetchedAt {
            HStack(spacing: 4) {
                Text(model.t("CACHED"))
                Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                Spacer(minLength: 0)
            }
            .font(.system(size: 8, design: .monospaced)).opacity(0.75)
            .padding(.top, 2)
        }
    }

}
