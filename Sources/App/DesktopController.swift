import AppKit
import SwiftUI

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
    private var screenID: NSNumber?
    private var anchor = AntennaAnchor(x: 1, y: 0.5)
    private let placementDefaults: UserDefaults
    private var smokeTesting: Bool { CommandLine.arguments.contains("--smoke-test") }

    override init() {
        // Native interaction testing must never change the installed radio's data.
        if CommandLine.arguments.contains("--setup-preview") {
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
        model.onPlacementChange = { [weak self] in self?.resetPlacement() }
        model.onLanguageChange = { [weak self] in self?.updateMenu() }
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
                if self?.model.setupOpen == true { return event }
                if self?.model.settingsOpen == true { self?.model.settingsOpen = false }
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
        savePlacement()
        position()
    }
    private func position() {
        guard panel != nil else { return }
        let visible = screen.visibleFrame
        let antenna = anchor.frame(visible: visible)
        let frame = model.isExpanded ? RadioPlacement.expandedFrame(anchor: antenna, visible: visible, left: model.edge == "Left") : antenna
        panel.setFrame(frame, display: true)
    }
    private func windowDragFinished() {
        guard panel != nil, !NSScreen.screens.isEmpty else { return }
        let displays = NSScreen.screens
        let index = RadioPlacement.screenIndex(frame: panel.frame, screens: displays.map(\.frame)) ?? 0
        let target = displays[index]
        screenID = target.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        let moved = RadioPlacement.clamp(panel.frame, visible: target.visibleFrame)
        panel.setFrame(moved, display: true)
        let antenna = model.isExpanded ? RadioPlacement.antennaFrame(expanded: moved, visible: target.visibleFrame, left: model.edge == "Left") : moved
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
        model.isExpanded = true
        panel.contentView = NSHostingView(rootView: RadioView(model: model))
        position()
        panel.makeKeyAndOrderFront(nil)
        if !smokeTesting { model.refreshIfNeeded() }
    }
    func tuck() {
        guard panel != nil else { return }
        model.settingsOpen = false
        model.isExpanded = false
        panel.contentView = NSHostingView(rootView: EdgeTab(model: model))
        position()
        panel.orderFrontRegardless()
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
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    private func runWindowSmokeTest() {
        verifyDragTracking()
        tuck()
        let collapsed = panel.frame
        precondition(collapsed.width == 54 && collapsed.height == 126)
        precondition(screen.visibleFrame.contains(collapsed))
        precondition(panel.level.rawValue > NSWindow.Level.normal.rawValue)
        precondition(!panel.hidesOnDeactivate)
        reveal()
        let expanded = panel.frame
        precondition(expanded.width == 374 && expanded.height == 416)
        precondition(screen.visibleFrame.contains(expanded))
        tuck()
        precondition(panel.frame == collapsed)
        print("PASS native panel tuck → reveal → tuck: \(collapsed) / \(expanded)")
        NSApp.terminate(nil)
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
        precondition(commits == 0 && testWindow.frame.origin == CGPoint(x: 100, y: 100))
        handle.mouseDown(with: event(.leftMouseDown, 20, 20))
        handle.mouseDragged(with: event(.leftMouseDragged, 35, 70))
        precondition(commits == 0 && testWindow.frame.origin == CGPoint(x: 115, y: 150))
        // Release five points farther than the last drag event, in the moved window.
        handle.mouseUp(with: event(.leftMouseUp, 25, 25))
        precondition(commits == 1 && testWindow.frame.origin == CGPoint(x: 120, y: 155))
        print("PASS native drag: no-op click, movement before release, final release coordinate, single commit")
    }
}
