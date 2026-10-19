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
                         verticalCorrection: model.botVerticalCorrection,
                         antennaLift: antennaLift, monitor: monitor, language: model.language, now: context.date,
                         toggle: { model.onBotExpansion?(!model.botExpanded) },
                         pull: { model.onBotExpansion?($0) },
                         open: { model.channel = .codex; model.onReveal?() },
                         antennaChanged: { antennaLift = $0 },
                         moved: { model.onWindowDragFinished?() }, dragBegan: { model.onBotDragBegan?() }, dragEnded: { model.onBotDragEnded?() })
        }
        .frame(width: model.botRoomReserved ? BotGeometry.fullWidth : BotGeometry.compactWidth,
               height: model.botRoomReserved ? BotGeometry.height : BotGeometry.compactHeight,
               alignment: model.edge == "Left" ? .bottomLeading : .bottomTrailing)
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
    var verticalCorrection: CGFloat = 0
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
    private var pose: BotGeometry { BotGeometry(progress: progress, left: left, originCorrection: originCorrection, verticalCorrection: verticalCorrection) }
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
            AntennaArtwork(classic: classic, extensionAmount: antennaLift, showsBase: false)
                .position(x: pose.centerX, y: pose.antennaY).allowsHitTesting(false)
            ForEach([-1.0, 1.0], id: \.self) { side in
                TokenBotArm(pose: pose, hand: side, classic: classic).allowsHitTesting(false)
            }
            TokenBotGlove(classic: classic, right: false, layer: .rear).scaleEffect(pose.gloveScale)
                .position(pose.leftGrip).allowsHitTesting(false)
            TokenBotGlove(classic: classic, right: true, layer: .rear).scaleEffect(pose.gloveScale)
                .position(pose.rightGrip).allowsHitTesting(false)
            TokenBotShell(classic: classic, pose: pose).position(x: pose.centerX, y: pose.shellY).allowsHitTesting(false)
            antenna.position(x: pose.centerX, y: pose.shellTop - 48.5)
            screen.position(x: pose.centerX, y: pose.screenY)
            glove(right: false).position(pose.leftGrip)
            glove(right: true).position(pose.rightGrip)
            WindowDragHandle(hint: t("Drag the bot's base to move Catecho"), onStarted: dragBegan, onEnded: dragEnded, onFinished: moved)
                .frame(width: pose.shellWidth - 8, height: 8).position(x: pose.centerX, y: pose.bottomY - 4)
        }
        .frame(width: BotGeometry.fullWidth, height: BotGeometry.height)
    }
    private var antenna: some View {
        Color.clear.frame(width: 54, height: 97).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { antennaChanged(min(AntennaPull.distance, max(0, -$0.translation.height))) }
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
        Button(action: toggle) {
            TokenBotGlove(classic: classic, right: right, layer: .grip).scaleEffect(pose.gloveScale)
                .frame(width: 10 + 20 * pose.progress, height: 18 + 22 * pose.progress).contentShape(Rectangle())
        }
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
                Color.clear
                screenFace.opacity(min(1, max(0, (pose.progress - 0.12) / 0.5)))
            }
            .frame(width: pose.screenWidth, height: pose.screenHeight)
            .clipShape(RoundedRectangle(cornerRadius: 3 + 5 * pose.progress))
            .contentShape(RoundedRectangle(cornerRadius: 3 + 5 * pose.progress))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.radioInk)
        .help(expanded
              ? [t("Click the belly to expand or retract the token dashboard."), scope, t(status)].filter { !$0.isEmpty }.joined(separator: "\n")
              : t("Expand token dashboard"))
        .accessibilityLabel(expanded
                            ? [t("Retract token dashboard"), scope, monitor.reading(now: now) + " " + unit, t(status)].filter { !$0.isEmpty }.joined(separator: ", ")
                            : t("Expand token dashboard"))
    }
    private var screenFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3 + 5 * pose.progress)
                .fill(Color.radioPaper.shadow(.inner(color: .black.opacity(classic ? 0.22 : 0), radius: 1 + 2 * pose.progress, x: 0.5, y: 1)))
                .overlay(RoundedRectangle(cornerRadius: 3 + 5 * pose.progress).stroke(Color.radioInk.opacity(0.4), lineWidth: 0.6))
                .overlay(RoundedRectangle(cornerRadius: 3 + 5 * pose.progress).stroke(.white.opacity(classic ? 0.65 : 0), lineWidth: 0.5).offset(y: 0.7))
                .frame(width: pose.screenWidth, height: pose.screenHeight)
            fullReading.frame(width: max(0, pose.screenWidth - 20)).fixedSize(horizontal: false, vertical: true)
                .scaleEffect(min(1, pose.screenHeight / 60))
                .opacity(max(0, (pose.progress - 0.35) / 0.65))
                .frame(width: max(0, pose.screenWidth - 20), height: pose.screenHeight - 4).clipped()
        }
    }
    private var fullReading: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("CODEX").tracking(2)
                Spacer()
                if !status.isEmpty { statusIcon }
                Text(t(monitor.window.label)).tracking(1)
            }.font(.system(size: 8, weight: .medium, design: .monospaced))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(monitor.reading(now: now, compact: true)).font(.system(size: 21, weight: .medium, design: .serif)).monospacedDigit()
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
