import SwiftUI

struct TokenBotView: View {
    @ObservedObject var model: RadioModel
    @ObservedObject var monitor: CodexMonitorModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0
    @State private var antennaLift: CGFloat = 0
    init(model: RadioModel) { self.model = model; monitor = model.codex }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            TokenBotPose(progress: progress, left: model.edge == "Left", classic: model.isClassic, originCorrection: model.botOriginCorrection,
                         antennaLift: antennaLift, monitor: monitor, language: model.language, now: context.date,
                         toggle: { model.onBotExpansion?(!model.botExpanded) },
                         pull: { model.onBotExpansion?($0) },
                         open: { model.channel = .codex; model.onReveal?() },
                         antennaChanged: { antennaLift = $0 },
                         moved: { model.onWindowDragFinished?() }, dragBegan: { model.onBotDragBegan?() }, dragEnded: { model.onBotDragEnded?() })
        }
        .frame(width: model.botRoomReserved ? BotGeometry.fullWidth : BotGeometry.compactWidth,
               height: BotGeometry.height, alignment: model.edge == "Left" ? .leading : .trailing)
        .clipped()
        .onChange(of: model.botExpanded) { _, value in
            withAnimation(reduceMotion ? nil : .timingCurve(0.22, 0.75, 0.18, 1, duration: BotGeometry.duration)) { progress = value ? 1 : 0 }
        }
        .onAppear { progress = model.botExpanded ? 1 : 0 }
        .preferredColorScheme(.light)
    }
}

/// The pose is animatable as a whole: no independent hand/screen timers can drift.
struct TokenBotPose: View, Animatable {
    var progress: Double
    let left: Bool
    let classic: Bool
    var originCorrection: CGFloat = 0
    var antennaLift: CGFloat = 0
    let monitor: CodexMonitorModel
    let language: RadioLanguage
    let now: Date
    var toggle: () -> Void = {}
    var pull: (Bool) -> Void = { _ in }
    var open: () -> Void = {}
    var antennaChanged: (CGFloat) -> Void = { _ in }
    var moved: () -> Void = {}
    var dragBegan: () -> Void = {}
    var dragEnded: () -> Void = {}
    var animatableData: Double { get { progress } set { progress = newValue } }
    private var pose: BotGeometry { BotGeometry(progress: progress, left: left, originCorrection: originCorrection) }
    private func t(_ text: String) -> String { language.text(text) }
    private var expanded: Bool { progress > 0.5 }
    private var scope: String { monitor.title(for: monitor.selectedSessionID, language: language) }
    private var unit: String { t(monitor.window == .second ? "tokens / sec" : "tokens") }
    private var status: String {
        guard let snapshot = monitor.snapshot, !snapshot.isIndexing else { return "INDEXING" }
        if snapshot.issue != nil { return "SAVED / UNAVAILABLE" }
        return snapshot.warning != nil ? "PARTIAL HISTORY" : ""
    }
    var body: some View {
        ZStack(alignment: .topLeading) {
            TokenBotShell(classic: classic).position(x: pose.centerX, y: 131)
            antenna.position(x: pose.centerX, y: 29)
            ForEach([-1.0, 1.0], id: \.self) { side in
                TokenBotArm(centerX: pose.centerX, progress: pose.progress, hand: side, classic: classic)
            }
            screen.position(x: pose.centerX, y: pose.screenY)
            glove(right: false).position(x: pose.leftGrip.x - 7, y: pose.leftGrip.y)
            glove(right: true).position(x: pose.rightGrip.x + 7, y: pose.rightGrip.y)
            WindowDragHandle(hint: t("Drag the bot's base to move Catecho"), onStarted: dragBegan, onEnded: dragEnded, onFinished: moved)
                .frame(width: 100, height: 21).position(x: pose.centerX, y: 197)
        }
        .frame(width: BotGeometry.fullWidth, height: BotGeometry.height)
    }
    private var antenna: some View {
        TokenBotAerial(classic: classic, lift: antennaLift)
            .frame(width: 44, height: 54).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { antennaChanged(min(12, max(0, -$0.translation.height))) }
                .onEnded { value in
                    antennaChanged(0)
                    if (abs(value.translation.width) < 4 && abs(value.translation.height) < 4) || AntennaPull.opensRadio(value.translation) { open() }
                })
            .help(t("Pull the antenna upward to open. Click also opens."))
            .accessibilityHidden(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(t("Open Catecho"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { open() }
    }
    private func glove(right: Bool) -> some View {
        Button(action: toggle) { TokenBotGlove(classic: classic, right: right).frame(width: 34, height: 44).contentShape(Rectangle()) }
            .buttonStyle(.plain)
            .highPriorityGesture(DragGesture(minimumDistance: 8).onEnded { value in
                if let target = BotGeometry.dragTarget(translation: value.translation, hand: right ? 1 : -1) { pull(target) }
            })
            .help(t("Pull a glove outward to expand, inward to retract."))
            .accessibilityLabel(t(expanded ? "Retract token dashboard" : "Expand token dashboard"))
    }
    private var screen: some View {
        Button(action: toggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(BotMaterial.cream(classic))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.radioInk.opacity(0.45), lineWidth: 0.7))
                    .shadow(color: .black.opacity(classic ? 0.18 : 0), radius: 2, y: 2)
                    .frame(width: pose.screenWidth, height: 68 + 10 * pose.progress)
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.radioPaper.shadow(.inner(color: .black.opacity(classic ? 0.22 : 0), radius: 3, x: 1, y: 2)))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(classic ? 0.75 : 0), lineWidth: 0.7))
                    .frame(width: pose.screenWidth - 8, height: 60 + 10 * pose.progress)
                compactReading.opacity(1 - min(1, pose.progress * 2.5))
                fullReading.opacity(max(0, (pose.progress - 0.35) / 0.65))
                    .frame(width: pose.screenWidth - 36).clipped()
            }
            .frame(width: pose.screenWidth, height: 68 + 10 * pose.progress)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.radioInk)
        .help([t("Click the belly to expand or retract the token dashboard."), scope, t(status), t("Uses the selected time view; readings update about every five seconds while tucked.")].filter { !$0.isEmpty }.joined(separator: "\n"))
        .accessibilityLabel([t(expanded ? "Retract token dashboard" : "Expand token dashboard"), scope, monitor.reading(now: now) + " " + unit, t(status)].filter { !$0.isEmpty }.joined(separator: ", "))
    }
    private var compactReading: some View {
        VStack(spacing: 4) {
            Text(monitor.reading(now: now, compact: true)).font(.system(size: 20, weight: .medium, design: .serif)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            HStack(spacing: 3) {
                Text(t(monitor.window.label)).font(.system(size: 7, weight: .medium, design: .monospaced)).tracking(1)
                if !status.isEmpty { statusIcon }
            }
        }.frame(width: 68)
    }
    private var fullReading: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("CODEX").tracking(2)
                Spacer()
                if !status.isEmpty { statusIcon }
                Text(t(monitor.window.label)).tracking(1)
            }.font(.system(size: 8, weight: .medium, design: .monospaced))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(monitor.reading(now: now, compact: true)).font(.system(size: 25, weight: .medium, design: .serif)).monospacedDigit()
                Text(unit).font(.system(size: 9))
            }.lineLimit(1).minimumScaleFactor(0.7)
            Rectangle().fill(Color.radioInk.opacity(0.3)).frame(height: 0.5)
            Text(scope).font(.system(size: 9)).lineLimit(1).truncationMode(.middle)
        }.padding(.horizontal, 3)
    }
    private var statusIcon: some View {
        Image(systemName: status == "INDEXING" ? "clock" : "exclamationmark.triangle").font(.system(size: 8)).accessibilityHidden(true)
    }
}
