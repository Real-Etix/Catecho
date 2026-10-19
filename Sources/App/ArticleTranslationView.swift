import AppKit
import SwiftUI
import Translation
import NaturalLanguage

struct RadioStoryContent: View {
    @ObservedObject var model: RadioModel
    let story: RadioItem
    var translated: TranslatedArticle? = nil
    var translationLabel: String? = nil
    var actionTitle: String? = nil
    var actionHelp: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(story.source.components(separatedBy: " · ").map(model.t).joined(separator: " · ")).lineLimit(1).help(story.source)
                if let date = story.publishedAt { Text("·"); Text(date, format: .dateTime.month(.abbreviated).day()) }
                Spacer(minLength: 0)
                if let translationLabel { Text(model.t(translationLabel)).font(.system(size: 7)).lineLimit(1) }
            }.font(.system(size: 9, weight: .medium, design: .monospaced)).opacity(0.7)
            Button { model.openSource() } label: {
                Text(translated?.title ?? model.t(story.title)).font(.system(size: 18, weight: .medium, design: .serif))
                    .lineLimit(3).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain).help(model.t("Open the original source"))
            if let metric = story.metric {
                Text(model.language.metric(metric)).font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            let excerpt = translated?.excerpt ?? story.excerpt
            if model.channel == .nba, story.metric == "SCHEDULED", let date = story.publishedAt {
                Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                    .font(.system(size: 13, weight: .medium)).lineLimit(2)
                Text(model.t("Your local time")).font(.system(size: 9)).opacity(0.65)
            } else {
                Text(excerpt.isEmpty ? model.t("Open the source to read the full story.") : excerpt)
                    .font(.system(size: 12)).lineSpacing(2).lineLimit(model.channel == .nba ? 3 : story.metric == nil ? 3 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading).opacity(0.85)
            }
            HStack(spacing: 5) {
                Button { model.openSource() } label: {
                    HStack(spacing: 4) { Text(model.t("Read source")); Image(systemName: "arrow.up.right").font(.system(size: 8)) }
                }.buttonStyle(.plain)
                Spacer(minLength: 0)
                if let actionTitle {
                    Button(model.t(actionTitle)) { action?() }
                        .buttonStyle(.plain).disabled(action == nil)
                        .help(model.t(actionHelp ?? actionTitle))
                }
            }.font(.system(size: 10, weight: .medium)).padding(.top, 1)
        }.padding(.top, 10)
    }
}

@available(macOS 15, *)
struct NativeArticleContent: View {
    @ObservedObject var model: RadioModel
    let request: ArticleTranslationRequest
    @State private var configuration: TranslationSession.Configuration?
    @State private var translation: TranslatedArticle?
    @State private var original = false
    @State private var state = Phase.checking
    private enum Phase { case checking, unchanged, needsDownload, translating, ready, unsupported, failed }

    var body: some View {
        RadioStoryContent(model: model, story: request.item,
                          translated: original ? nil : translation,
                          translationLabel: translation == nil ? nil : (original ? "Original" : "Machine translation"),
                          actionTitle: actionTitle, actionHelp: help, action: action)
            .task { await checkAvailability() }
            .translationTask(configuration) { session in
                state = .translating
                do {
                    // Translate actual text so automatic source detection can prepare the language pair.
                    let parts = request.parts.map { TranslationSession.Request(sourceText: $0.value, clientIdentifier: $0.key) }
                    let replies = try await session.translations(from: parts)
                    try Task.checkCancellation()
                    var values: [String: String] = [:]
                    for reply in replies { if let id = reply.clientIdentifier { values[id] = reply.targetText } }
                    guard let result = request.record(responses: values) else { state = .failed; return }
                    // The view identity includes source text + target script. Never overwrite source feed data.
                    try? ArticleTranslationCache.local.save(result, key: request.key)
                    translation = result
                    original = false
                    state = .ready
                } catch {
                    if !Task.isCancelled { state = .failed }
                }
            }
    }
    private var actionTitle: String? {
        switch state {
        case .checking, .unchanged: return nil
        case .needsDownload: return "Download languages"
        case .translating: return "Translating…"
        case .ready: return original ? "Translation" : "Original"
        case .unsupported: return "Original"
        case .failed: return "Try again"
        }
    }
    private var help: String? {
        switch state {
        case .needsDownload: return "Translation needs a language download. The original is shown."
        case .unsupported: return "This language pair is not supported. The original is shown."
        case .failed: return "Translation unavailable. The original is shown."
        default: return actionTitle
        }
    }
    private var action: (() -> Void)? {
        switch state {
        case .ready: return { original.toggle() }
        case .needsDownload: return { startTranslation() }
        case .failed: return { Task { await checkAvailability() } }
        default: return nil
        }
    }
    @MainActor private func checkAvailability() async {
        if let saved = ArticleTranslationCache.local.load(request.key) {
            translation = saved; state = .ready; return
        }
        guard !request.parts.isEmpty else { state = .unchanged; return }
        let sample = request.parts.sorted { $0.key < $1.key }.map(\.value).joined(separator: "\n")
        let target = request.language.resolved().rawValue
        if NLLanguageRecognizer.dominantLanguage(for: sample)?.rawValue == target {
            state = .unchanged; return
        }
        do {
            let status = try await LanguageAvailability().status(for: sample, to: Locale.Language(identifier: target))
            try Task.checkCancellation()
            switch status {
            case .installed: startTranslation()
            case .supported: state = .needsDownload
            case .unsupported: state = .unsupported
            @unknown default: state = .unsupported
            }
        } catch { if !Task.isCancelled { state = .failed } }
    }
    private func startTranslation() {
        state = .translating
        if configuration == nil {
            configuration = TranslationSession.Configuration(source: nil, target: Locale.Language(identifier: request.language.resolved().rawValue))
        } else { configuration?.invalidate() }
    }
}
