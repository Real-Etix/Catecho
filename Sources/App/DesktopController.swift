import AppKit
import SwiftUI
import Combine

final class RadioPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class DesktopController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model: RadioModel
    private var panel: RadioPanel!
    private var statusItem: NSStatusItem!
    private var clickMonitor: Any?
    private var localMonitor: Any?
    private var timer: Timer?
    private var botRetraction: Task<Void, Never>?
    private var botDragging = false
    private var botShrinkPending = false
    private var previewObservation: AnyCancellable?
    private var screenID: NSNumber?
    private var anchor = AntennaAnchor(x: 1, y: 0.5)
    private let placementDefaults: UserDefaults
    private var smokeTesting: Bool { CommandLine.arguments.contains("--smoke-test") }

    override init() {
        // Native interaction testing must never change the installed radio's data.
        if CommandLine.arguments.contains("--codex-preview") || CommandLine.arguments.contains("--codex-live-preview") {
            let preferences = UserDefaults(suiteName: "Catecho.CodexPreview")!
            placementDefaults = preferences
            let cache = FileManager.default.temporaryDirectory.appendingPathComponent("CatechoCodexPreview")
            let monitor = CodexMonitorModel(preferences: preferences, historyDirectory: cache, simulated: !CommandLine.arguments.contains("--codex-live-preview"))
            model = RadioModel(preview: true, preferences: preferences, cacheDirectory: cache, codexMonitor: monitor)
            model.configuration = FeedConfiguration()
            model.configuration.enabledChannels = ["codex"]
            model.channel = .codex
        } else if CommandLine.arguments.contains("--setup-preview") {
            let preferences = UserDefaults(suiteName: "Catecho.SetupPreview")!
            placementDefaults = preferences
            model = RadioModel(preferences: preferences, cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("CatechoSetupPreview"))
        } else {
            placementDefaults = .standard
            model = RadioModel()
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = RadioPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Catecho"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = false
        screenID = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        restorePlacement()
        model.onWindowDragFinished = { [weak self] in self?.windowDragFinished() }
        model.onTuck = { [weak self] in self?.tuck() }
        model.onReveal = { [weak self] in self?.reveal() }
        model.onBotExpansion = { [weak self] in self?.setBotExpanded($0) }
        model.onBotDragBegan = { [weak self] in self?.botDragging = true }
        model.onBotDragEnded = { [weak self] in
            guard let self else { return }
            self.botDragging = false
            if self.botShrinkPending { self.finishBotRetraction() }
        }
        model.onPlacementChange = { [weak self] in self?.resetPlacement() }
        model.onLanguageChange = { [weak self] in self?.updateMenu() }
        previewObservation = model.codex.$enabled.combineLatest(model.codex.$showEdgePreview)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                guard let self, !self.model.isExpanded else { return }
                if !self.showsCodexPreview { self.resetBot() }
                self.position()
            }
        createMenu()
        if model.setupOpen && !smokeTesting {
            reveal()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            tuck()
            if CommandLine.arguments.contains("--show") { reveal() }
            if !smokeTesting { model.prepareEdition() }
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.handleOutsideClick() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 {
                if self?.model.codex.isChatPickerPresented == true { return event }
                if self?.model.setupOpen == true { return event }
                if self?.model.botExpanded == true && self?.model.isExpanded == false { self?.setBotExpanded(false) }
                else if self?.model.settingsOpen == true { self?.model.settingsOpen = false }
                else { self?.tuck() }
                return nil
            }
            return event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.periodicRefresh() }
        }
        timer?.tolerance = 5
        if CommandLine.arguments.contains("--smoke-test") { runWindowSmokeTest() }
    }

    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: model.t("Open Catecho"))
        updateMenu()
    }
    private func updateMenu() {
        guard statusItem != nil else { return }
        statusItem.button?.setAccessibilityLabel(model.t("Open Catecho"))
        let menu = NSMenu()
        menu.addItem(withTitle: model.t("Open Catecho"), action: #selector(openFromMenu), keyEquivalent: "o").target = self
        menu.addItem(withTitle: model.t("Fetch latest edition"), action: #selector(refreshFromMenu), keyEquivalent: "r").target = self
        menu.addItem(withTitle: model.t("Move to this display"), action: #selector(moveToDisplay), keyEquivalent: "").target = self
        let setup = menu.addItem(withTitle: model.t("Set up your radio…"), action: #selector(openSetup), keyEquivalent: "")
        setup.target = self; setup.tag = 77
        menu.delegate = self
        menu.addItem(.separator())
        menu.addItem(withTitle: model.t("Quit Catecho"), action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: 77)?.isEnabled = !model.settingsOpen && !model.setupOpen
    }
    @objc private func openSetup() { model.beginSetup() }
    private var screen: NSScreen {
        NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == screenID } ?? NSScreen.main ?? NSScreen.screens[0]
    }
    private func restorePlacement() {
        if let id = placementDefaults.object(forKey: "antenna.monitorID") as? NSNumber { screenID = id }
        if placementDefaults.object(forKey: "antenna.x") != nil {
            anchor = AntennaAnchor(x: placementDefaults.double(forKey: "antenna.x"), y: placementDefaults.double(forKey: "antenna.y"))
        } else {
            anchor = AntennaAnchor(x: model.edge == "Left" ? 0 : 1, y: 0.5)
        }
    }
    private func savePlacement() {
        placementDefaults.set(Double(anchor.x), forKey: "antenna.x")
        placementDefaults.set(Double(anchor.y), forKey: "antenna.y")
        placementDefaults.set(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")], forKey: "antenna.monitorID")
    }
    private func resetPlacement() {
        anchor = AntennaAnchor(x: model.edge == "Left" ? 0 : 1, y: 0.5)
        model.botOriginCorrection = 0; model.botVerticalCorrection = 0
        savePlacement()
        position()
    }
    private func position() {
        guard panel != nil else { return }
        let visible = screen.visibleFrame
        let left = model.edge == "Left"
        let compact = anchor.frame(visible: visible)
        let reservedCorrection = CGSize(width: model.botOriginCorrection, height: model.botVerticalCorrection)
        let tucked = showsCodexPreview
            ? BotGeometry.windowFrame(anchor: compact, visible: visible, left: left, expanded: model.botRoomReserved, reservedCorrection: reservedCorrection)
            : RadioPlacement.tuckedFrame(anchor: compact, visible: visible, left: left, preview: false)
        let offset = model.botRoomReserved ? BotGeometry.reservationOffset(compact: compact, reserved: tucked, left: left) : .zero
        model.botOriginCorrection = offset.width; model.botVerticalCorrection = offset.height
        let antenna = showsCodexPreview
            ? BotGeometry.anchorFrame(window: tucked, visible: visible, left: left)
            : RadioPlacement.antennaFrame(tucked: tucked, visible: visible, left: left, preview: false)
        let frame = model.isExpanded ? RadioPlacement.expandedFrame(anchor: antenna, visible: visible, left: left) : tucked
        panel.setFrame(frame, display: true)
    }
    private var showsCodexPreview: Bool { model.codex.enabled && model.codex.showEdgePreview }
    private func windowDragFinished() {
        guard panel != nil, !NSScreen.screens.isEmpty else { return }
        let displays = NSScreen.screens
        let index = RadioPlacement.screenIndex(frame: panel.frame, screens: displays.map(\.frame)) ?? 0
        let target = displays[index]
        screenID = target.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let moved = RadioPlacement.clamp(panel.frame, visible: target.visibleFrame)
        panel.setFrame(moved, display: true)
        let antenna: CGRect
        if model.isExpanded { antenna = RadioPlacement.antennaFrame(expanded: moved, visible: target.visibleFrame, left: model.edge == "Left") }
        else if showsCodexPreview {
            antenna = BotGeometry.anchorFrame(window: moved, visible: target.visibleFrame, left: model.edge == "Left",
                                             reservedCorrection: model.botRoomReserved ? model.botOriginCorrection : 0,
                                             reservedVerticalCorrection: model.botRoomReserved ? model.botVerticalCorrection : 0)
        }
        else { antenna = RadioPlacement.antennaFrame(tucked: moved, visible: target.visibleFrame, left: model.edge == "Left", preview: false) }
        anchor = AntennaAnchor(frame: antenna, visible: target.visibleFrame)
        savePlacement()
    }
    func reveal() {
        guard panel != nil else { return }
        if model.isExpanded && model.setupOpen {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        resetBot()
        model.isExpanded = true
        let host = NSHostingView(rootView: RadioView(model: model))
        host.sizingOptions = [] // The controller owns this borderless window's frame.
        panel.contentView = host
        position()
        panel.makeKeyAndOrderFront(nil)
        if !smokeTesting { model.refreshIfNeeded() }
    }
    func tuck() {
        guard panel != nil else { return }
        resetBot()
        model.settingsOpen = false
        model.isExpanded = false
        let host = NSHostingView(rootView: EdgeTab(model: model))
        host.sizingOptions = []
        panel.contentView = host
        position()
        panel.orderFrontRegardless()
    }
    private func resetBot() {
        botRetraction?.cancel(); botRetraction = nil
        botDragging = false; botShrinkPending = false
        model.botExpanded = false
        model.botRoomReserved = false
        model.botOriginCorrection = 0; model.botVerticalCorrection = 0
    }
    private func setBotExpanded(_ expanded: Bool, animated: Bool = true) {
        guard !model.isExpanded, showsCodexPreview else { return }
        botRetraction?.cancel(); botRetraction = nil
        botShrinkPending = false
        if expanded {
            if !model.botRoomReserved {
                model.botRoomReserved = true
                position()
            }
            model.botExpanded = true
            panel.makeKeyAndOrderFront(nil)
        } else {
            model.botExpanded = false
            if !animated || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                finishBotRetraction()
            } else {
                botRetraction = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(BotGeometry.closingDuration + 0.04))
                    guard !Task.isCancelled, let self, !self.model.isExpanded, !self.model.botExpanded else { return }
                    self.finishBotRetraction()
                }
            }
        }
    }
    private func finishBotRetraction() {
        guard !model.isExpanded, !model.botExpanded else { return }
        guard !botDragging else { botShrinkPending = true; return }
        botShrinkPending = false
        model.botRoomReserved = false
        position()
    }
    private func handleOutsideClick() {
        guard model.isExpanded, !model.pinned, !model.setupOpen else { return }
        let point = NSEvent.mouseLocation
        // Include popovers, which are separate windows belonging to this app.
        if NSApp.windows.contains(where: { $0.isVisible && $0.frame.contains(point) }) { return }
        tuck()
    }
    @objc private func openFromMenu() { reveal() }
    @objc private func refreshFromMenu() { model.refresh() }
    @objc private func moveToDisplay() {
        if let target = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
            screenID = target.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        }
        resetPlacement()
    }
    @objc private func screensChanged() { position() }
    @objc private func didWake() { model.refreshIfNeeded(); position() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        timer?.invalidate()
        botRetraction?.cancel()
        previewObservation?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    private func smokeCheck(_ condition: @autoclosure () -> Bool, _ message: String = "", line: UInt = #line) {
        guard condition() else {
            let diagnostic = "FAIL native smoke line \(line): \(message); frame=\(panel.frame), reserved=\(model.botRoomReserved), expanded=\(model.botExpanded)\n"
            FileHandle.standardError.write(Data(diagnostic.utf8))
            fatalError(diagnostic)
        }
    }
    private func runWindowSmokeTest() {
        verifyDragTracking()
        tuck()
        let collapsed = panel.frame
        smokeCheck(collapsed.width == 54 && collapsed.height == 126)
        smokeCheck(screen.visibleFrame.contains(collapsed))
        smokeCheck(panel.level.rawValue > NSWindow.Level.normal.rawValue)
        smokeCheck(!panel.hidesOnDeactivate)
        if showsCodexPreview {
            setBotExpanded(true, animated: false)
            smokeCheck(panel.frame.width == BotGeometry.fullWidth && panel.frame.height == BotGeometry.height && screen.visibleFrame.contains(panel.frame))
            model.onBotDragBegan?()
            setBotExpanded(false, animated: false)
            smokeCheck(panel.frame.width == BotGeometry.fullWidth, "Retraction must not resize during base tracking")
            model.onBotDragEnded?()
            smokeCheck(panel.frame == collapsed, "Compact frame must return to \(collapsed)")
            setBotExpanded(true, animated: false)
        }
        reveal()
        let expanded = panel.frame
        smokeCheck(expanded.width == 374 && expanded.height == 416)
        smokeCheck(screen.visibleFrame.contains(expanded))
        tuck()
        smokeCheck(panel.frame == collapsed)
        if showsCodexPreview && CommandLine.arguments.contains("--codex-preview") { verifyBotRepositioning() }
        print("PASS native panel tuck → reveal → tuck: \(collapsed) / \(expanded)")
        NSApp.terminate(nil)
    }
    private func verifyBotRepositioning() {
        let savedAnchor = anchor
        let visible = screen.visibleFrame
        anchor = AntennaAnchor(x: model.edge == "Left" ? 1 : 0, y: 1)
        position()
        setBotExpanded(true, animated: false)
        smokeCheck(model.botVerticalCorrection == BotGeometry.compactHeight - BotGeometry.height)
        panel.setFrameOrigin(CGPoint(x: visible.midX - BotGeometry.fullWidth / 2, y: visible.midY - BotGeometry.height / 2))
        windowDragFinished()
        let moved = panel.frame
        let correction = CGSize(width: model.botOriginCorrection, height: model.botVerticalCorrection)
        position() // Wake and screen-parameter notifications use this path.
        smokeCheck(abs(panel.frame.minX - moved.minX) < 0.01 && abs(panel.frame.minY - moved.minY) < 0.01,
                   "Repositioning a dragged reserved panel must retain its current frame")
        smokeCheck(abs(model.botOriginCorrection - correction.width) < 0.01 && abs(model.botVerticalCorrection - correction.height) < 0.01)
        setBotExpanded(false, animated: false)
        let compact = panel.frame
        let closing = BotGeometry(progress: 0, left: model.edge == "Left", originCorrection: correction.width, verticalCorrection: correction.height)
        smokeCheck(abs(compact.midX - (moved.minX + closing.centerX)) < 0.01)
        smokeCheck(abs(compact.minY + 16 - (moved.maxY - closing.shellY)) < 0.01)
        anchor = savedAnchor; savePlacement(); position()
        print("PASS native reserved drag → display reposition → retract preserves both axes")
    }
    private func verifyDragTracking() {
        let testWindow = NSPanel(contentRect: CGRect(x: 100, y: 100, width: 374, height: 416), styleMask: [.borderless], backing: .buffered, defer: false)
        let handle = WindowDragHandleView(frame: CGRect(x: 0, y: 0, width: 374, height: 416))
        testWindow.contentView = handle
        var commits = 0
        handle.onFinished = { commits += 1 }
        func event(_ type: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: CGPoint(x: x, y: y), modifierFlags: [], timestamp: 0, windowNumber: testWindow.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        handle.mouseDown(with: event(.leftMouseDown, 20, 20))
        handle.mouseUp(with: event(.leftMouseUp, 20, 20))
        smokeCheck(commits == 0 && testWindow.frame.origin == CGPoint(x: 100, y: 100))
        handle.mouseDown(with: event(.leftMouseDown, 20, 20))
        handle.mouseDragged(with: event(.leftMouseDragged, 35, 70))
        smokeCheck(commits == 0 && testWindow.frame.origin == CGPoint(x: 115, y: 150))
        // Release five points farther than the last drag event, in the moved window.
        handle.mouseUp(with: event(.leftMouseUp, 25, 25))
        smokeCheck(commits == 1 && testWindow.frame.origin == CGPoint(x: 120, y: 155))
        print("PASS native drag: no-op click, movement before release, final release coordinate, single commit")
    }
}
