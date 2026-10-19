import AppKit
import SwiftUI

@main
struct LittleRadioApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        if let index = CommandLine.arguments.firstIndex(of: "--render-bot"), CommandLine.arguments.count > index + 1 {
            renderBot(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-codex"), CommandLine.arguments.count > index + 1 {
            renderCodex(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render"), CommandLine.arguments.count > index + 1 {
            renderPreviews(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            return
        }
        if CommandLine.arguments.contains("--geometry-test") {
            for visible in [CGRect(x: 0, y: 0, width: 1440, height: 875), CGRect(x: -1920, y: 100, width: 1920, height: 1080)] {
                for expanded in [true, false] { for left in [true, false] {
                    let frame = EdgeGeometry.frame(visible: visible, expanded: expanded, left: left)
                    precondition(visible.contains(frame))
                    precondition(frame.width == (expanded ? 374 : 54))
                    precondition(left ? frame.minX >= visible.minX : frame.maxX <= visible.maxX)
                } }
            }
            print("PASS: eight desktop edge/monitor geometry cases")
            return
        }
        let delegate = DesktopController()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    @MainActor static func renderBot(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let preferences = UserDefaults(suiteName: "Catecho.BotRender")!
        let model = RadioModel(preview: true, preferences: preferences)
        model.configuration.enabledChannels = ["codex"]
        model.codex.window = .lifetime
        model.codex.selectSession("preview-old")
        for language in [RadioLanguage.english, .simplified, .traditional] {
            for classic in [true, false] {
                for progress in [0.0, 0.5, 1.0] {
                    let content = TokenBotPose(progress: progress, left: false, classic: classic, monitor: model.codex, language: language, now: Date())
                        .padding(20).background(Color(red: 0.96, green: 0.95, blue: 0.92)).preferredColorScheme(.light)
                    let name = "bot-\(classic ? "Classic" : "Flat")-\(language.rawValue)-\(Int(progress * 100)).png"
                    renderNative(content, to: directory.appendingPathComponent(name), size: CGSize(width: BotGeometry.fullWidth + 40, height: BotGeometry.height + 40))
                    print("Rendered \(name)")
                }
            }
        }
    }

    @MainActor static func renderCodex(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let preferences = UserDefaults(suiteName: "Catecho.CodexRender")!
        let model = RadioModel(preview: true, preferences: preferences)
        model.configuration = FeedConfiguration()
        model.configuration.enabledChannels = ["codex"]
        model.channel = .codex; model.isExpanded = true
        for language in [RadioLanguage.english, .simplified, .traditional] {
            model.language = language
            for appearance in ["Classic", "Flat"] {
                model.appearance = appearance
                model.codex.window = .second
                renderNative(RadioView(model: model, previewLabel: "PREVIEW"), to: directory.appendingPathComponent("codex-\(appearance)-\(language.rawValue).png"))
                model.codex.window = .lifetime
                renderNative(RadioView(model: model, previewLabel: "PREVIEW"), to: directory.appendingPathComponent("codex-total-\(appearance)-\(language.rawValue).png"))
            }
        }
    }

    @MainActor static func renderPreviews(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let model = RadioModel(preview: true)
        model.language = .english
        model.isExpanded = true
        model.channel = .ai
        model.batches[.ai] = FeedBatch(items: [RadioItem(id: "preview", title: "A slower start. A clearer view.", excerpt: "Your chosen sources, gathered into a small daily edition. A few useful stories, with room to think.", source: "Design preview", url: URL(string: "https://huggingface.co/blog")!, publishedAt: nil, metric: nil)], fetchedAt: Date(), warning: nil)
        for variant in ["classic", "flat", "tuning", "offline"] {
            model.appearance = variant == "flat" ? "Flat" : "Classic"
            model.fetching.removeAll()
            model.failures.removeAll()
            if variant == "tuning" { model.batches[.ai] = nil; model.fetching.insert(.ai) }
            if variant == "offline" {
                model.batches[.ai] = FeedBatch(items: [RadioItem(id: "saved", title: "Your last edition is still here.", excerpt: "A lost connection doesn’t have to interrupt your morning. Read the saved stories and refresh when you’re ready.", source: "Design preview", url: URL(string: "https://huggingface.co/blog")!, publishedAt: nil, metric: nil)], fetchedAt: Date().addingTimeInterval(-7200), warning: nil)
                model.failures[.ai] = "The network is unavailable. Your saved edition is available."
            }
            let renderer = ImageRenderer(content: RadioView(model: model, previewLabel: "DESIGN PREVIEW"))
            renderer.scale = 2
            if let image = renderer.nsImage, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: directory.appendingPathComponent("radio-\(variant).png"))
                print("Rendered \(variant)")
            }
        }
        for language in [RadioLanguage.simplified, .traditional] {
            model.language = language
            model.appearance = "Classic"
            model.fetching.removeAll(); model.failures.removeAll()
            let simplified = language == .simplified
            model.batches[.ai] = FeedBatch(items: [RadioItem(id: "language-preview", title: simplified ? "慢一点开始，看得更清楚。" : "慢一點開始，看得更清楚。", excerpt: simplified ? "把你关心的来源，整理成一份小小的每日资讯。几条有用的消息，也留一点思考的空间。" : "把你關心的來源，整理成一份小小的每日資訊。幾條有用的消息，也留一點思考的空間。", source: simplified ? "设计预览" : "設計預覽", url: URL(string: "https://huggingface.co/blog")!, publishedAt: Date(), metric: nil)], fetchedAt: Date(), warning: nil)
            let renderer = ImageRenderer(content: RadioView(model: model, previewLabel: simplified ? "设计预览" : "設計預覽"))
            renderer.scale = 2
            if let tiff = renderer.nsImage?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: directory.appendingPathComponent("radio-\(language.rawValue).png"))
            }
        }
        model.language = .english
        for (name, tab, appearance) in [("back", 0, "Classic"), ("sources", 1, "Classic"), ("controls", 2, "Classic"), ("controls-flat", 2, "Flat"), ("back-flat", 0, "Flat")] {
            model.appearance = appearance
            renderNative(RadioSettings(model: model, initialTab: tab).padding(12), to: directory.appendingPathComponent("radio-\(name).png"))
        }
        model.appearance = "Classic"
        for language in [RadioLanguage.simplified, .traditional] {
            model.language = language
            model.appearance = "Classic"
            renderNative(RadioSettings(model: model).padding(12), to: directory.appendingPathComponent("radio-back-\(language.rawValue).png"))
            renderNative(RadioSettings(model: model, initialTab: 2).padding(12), to: directory.appendingPathComponent("radio-controls-\(language.rawValue).png"))
        }
        let antenna = ImageRenderer(content: HStack(alignment: .bottom, spacing: 45) {
            VStack(spacing: 12) {
                AntennaArtwork(classic: true)
                Text("Drag the base").font(.system(size: 12))
            }
            VStack(spacing: 12) {
                AntennaArtwork(classic: true, extensionAmount: AntennaPull.distance)
                Text("Pull up to open").font(.system(size: 12))
            }
        }.foregroundStyle(Color.radioInk).padding(30).background(Color(red: 0.96, green: 0.95, blue: 0.91)))
        antenna.scale = 3
        if let tiff = antenna.nsImage?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: directory.appendingPathComponent("antenna-preview.png"))
        }
    }

    // Native scroll views and macOS controls are not drawn by SwiftUI ImageRenderer.
    @MainActor private static func renderNative<Content: View>(_ content: Content, to url: URL, size: CGSize = CGSize(width: 374, height: 416)) {
        let frame = CGRect(origin: CGPoint(x: -2000, y: -2000), size: size)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        let view = NSHostingView(rootView: content)
        view.frame = CGRect(origin: .zero, size: frame.size)
        window.contentView = view
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        view.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: url) }
        }
        window.close()
    }
}
