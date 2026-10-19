import AppKit
import SwiftUI

/// A native drag region keeps window motion independent of SwiftUI view layout.
struct WindowDragHandle: NSViewRepresentable {
    var hint: String = "Drag to move Catecho"
    var onStarted: (() -> Void)? = nil
    var onEnded: (() -> Void)? = nil
    let onFinished: () -> Void
    func makeNSView(context: Context) -> WindowDragHandleView {
        let view = WindowDragHandleView()
        view.onFinished = onFinished
        view.onStarted = onStarted; view.onEnded = onEnded
        view.toolTip = hint
        return view
    }
    func updateNSView(_ view: WindowDragHandleView, context: Context) { view.onFinished = onFinished; view.onStarted = onStarted; view.onEnded = onEnded; view.toolTip = hint }
}

final class WindowDragHandleView: NSView {
    var onFinished: (() -> Void)?
    var onStarted: (() -> Void)?
    var onEnded: (() -> Void)?
    private var dragOrigin: CGPoint?
    private var pointerOrigin: CGPoint?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragOrigin = window.frame.origin
        pointerOrigin = window.convertPoint(toScreen: event.locationInWindow)
        onStarted?()
    }
    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragOrigin, let pointerOrigin else { return }
        let pointer = window.convertPoint(toScreen: event.locationInWindow)
        window.setFrameOrigin(CGPoint(x: dragOrigin.x + pointer.x - pointerOrigin.x,
                                      y: dragOrigin.y + pointer.y - pointerOrigin.y))
    }
    override func mouseUp(with event: NSEvent) {
        defer { dragOrigin = nil; pointerOrigin = nil; onEnded?() }
        guard let window, let dragOrigin else { return }
        mouseDragged(with: event)
        // Commit only at release; a header click must preserve the original tuck anchor.
        if window.frame.origin != dragOrigin { onFinished?() }
    }
}

struct AntennaArtwork: View {
    var classic: Bool
    var extensionAmount: CGFloat = 0
    var showsBase = true
    private var metal: LinearGradient {
        LinearGradient(colors: [Color(red: 0.40, green: 0.43, blue: 0.40), Color.white.opacity(0.95), Color(red: 0.56, green: 0.58, blue: 0.53)], startPoint: .leading, endPoint: .trailing)
    }
    var body: some View {
        let lift = min(AntennaPull.distance, max(0, extensionAmount))
        ZStack(alignment: .topLeading) {
            Capsule().fill(classic ? AnyShapeStyle(metal) : AnyShapeStyle(Color.radioPaper))
                .frame(width: 6, height: 55 + lift)
                .overlay(Capsule().stroke(Color.radioInk.opacity(0.7), lineWidth: 0.7))
                .position(x: 27, y: 99 - (55 + lift) / 2)
                .shadow(color: .black.opacity(classic ? 0.16 : 0), radius: 1, x: 1, y: 1)
            ForEach(0..<2) { band in
                RoundedRectangle(cornerRadius: 1).fill(Color.radioInk.opacity(0.6)).frame(width: 7, height: 2)
                    .position(x: 27, y: 69 + CGFloat(band) * 18 - lift * CGFloat(2 - band) / 3)
            }
            Circle().fill(classic ? AnyShapeStyle(metal) : AnyShapeStyle(Color.radioCream))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.radioInk.opacity(0.8), lineWidth: 0.8))
                .position(x: 27, y: 44 - lift)
            RoundedRectangle(cornerRadius: 6).fill(Color.radioInk.opacity(0.7)).frame(width: 12, height: 11).position(x: 27, y: 99)
            if showsBase { ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(classic ? AnyShapeStyle(LinearGradient(colors: [.white, .radioCream, Color(red: 0.79, green: 0.75, blue: 0.66)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.radioCream))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.radioInk.opacity(0.65), lineWidth: 0.8))
                    .shadow(color: .black.opacity(classic ? 0.22 : 0), radius: 2, x: 0, y: 2)
                HStack(spacing: 4) {
                    ForEach(0..<3) { _ in Capsule().fill(Color.radioInk.opacity(0.5)).frame(width: 2, height: 9) }
                }
            }.frame(width: 42, height: 26).position(x: 27, y: 110) }
        }.frame(width: 54, height: 126)
        .accessibilityHidden(true)
    }
}

struct EdgeTab: View {
    @ObservedObject var model: RadioModel
    @ObservedObject var monitor: CodexMonitorModel
    @State private var extensionAmount: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(model: RadioModel) { self.model = model; monitor = model.codex }
    var body: some View {
        Group {
            if showPreview { TokenBotView(model: model) }
            else { antenna }
        }.preferredColorScheme(.light)
    }
    private var showPreview: Bool { monitor.enabled && monitor.showEdgePreview }
    private var antenna: some View {
        ZStack(alignment: .top) {
            AntennaArtwork(classic: model.isClassic, extensionAmount: extensionAmount)
            Color.clear.frame(width: 54, height: 97).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in extensionAmount = min(AntennaPull.distance, max(0, -value.translation.height)) }
                    .onEnded { value in
                        let tap = abs(value.translation.width) < 4 && abs(value.translation.height) < 4
                        if tap || AntennaPull.opensRadio(value.translation) {
                            extensionAmount = 0
                            model.onReveal?()
                        } else {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) { extensionAmount = 0 }
                        }
                    })
                .help(model.t("Pull the antenna upward to open. Click also opens."))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.t("Open Catecho"))
                .accessibilityHint(model.t("Pull the tip up, or activate to open. Drag the base to move."))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { model.onReveal?() }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                WindowDragHandle(hint: model.t("Drag to move Catecho")) { model.onWindowDragFinished?() }
                    .frame(width: 48, height: 29)
                    .help(model.t("Drag this base to reposition the antenna"))
            }
        }.frame(width: 54, height: 126).preferredColorScheme(.light)
    }
}
