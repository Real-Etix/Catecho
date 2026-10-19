import Foundation
@main struct LanguageTests {
    static func main() {
        precondition(RadioLanguage.system.resolved(preferred: ["zh-Hant-HK", "en"]) == .traditional, "Hong Kong Traditional preference must resolve to Traditional Chinese")
        for code in ["zh-TW", "zh-HK", "zh-MO", "zh-Hant"] {
            precondition(RadioLanguage.system.resolved(preferred: [code]) == .traditional)
        }
        for code in ["zh-CN", "zh-SG", "zh-Hans", "zh"] {
            precondition(RadioLanguage.system.resolved(preferred: [code]) == .simplified)
        }
        precondition(RadioLanguage.traditional.resolved(preferred: ["en"]) == .traditional)
        precondition(RadioLanguage.system.resolved(preferred: ["ja", "en-GB"]) == .english)
        precondition(RadioLanguage.system.resolved(preferred: []) == .english)
        precondition(RadioLanguage.simplified.text("Radio settings") == "收音机设置")
        precondition(RadioLanguage.traditional.text("Radio settings") == "收音機設定")
        precondition(RadioLanguage.traditional.text("Unmapped diagnostic") == "Unmapped diagnostic")
        precondition(RadioLanguage.traditional.metric("1,234 total stars") == "1,234 顆星")
        precondition(RadioLanguage.simplified.metric("+123 stars today") == "+123 今日新增星标")
        precondition(RadioLanguage.traditional.metric("SCHEDULED") == "賽程")
        precondition(RadioLanguage.traditional.text("Flip to front") == "翻回正面")
        precondition(RadioLanguage.simplified.text("Flip to front") == "翻回正面")
        precondition(RadioLanguage.traditional.text("Close cover") == "合上蓋子", "The actual battery cover keeps its separate wording")
        for entry in RadioLanguage.strings {
            precondition(!entry.value.0.isEmpty && !entry.value.1.isEmpty, "Missing Chinese translation")
        }
        precondition(RadioLanguage.traditional.text("Source: The source returned HTTP 404. Try again later.") == "Source: 來源傳回 HTTP 404。請稍後重試。", "HTTP diagnostics must follow interface language")
        let item = RadioItem(id: "id", title: "owner/repository", excerpt: "An English description", source: "GitHub", url: URL(string: "https://github.com/owner/repository")!, publishedAt: nil, metric: "123 total stars")
        let request = ArticleTranslationRequest(item: item, language: .traditional, repository: true)
        precondition(request.parts == ["excerpt": "An English description"])
        precondition(request.record(responses: ["excerpt": "英文說明"]) == TranslatedArticle(title: "owner/repository", excerpt: "英文說明"), "Translation must preserve repository identifiers")
        precondition(request.record(responses: [:]) == nil, "Partial replies must not masquerade as completed translations")
        precondition(request.record(responses: ["excerpt": "  "]) == nil)
        let simplified = ArticleTranslationRequest(item: item, language: .simplified, repository: true)
        precondition(request.key != simplified.key, "Chinese scripts must have separate caches")
        let changed = RadioItem(id: "id", title: item.title, excerpt: "Changed description", source: item.source, url: item.url, publishedAt: nil, metric: item.metric)
        precondition(request.key != ArticleTranslationRequest(item: changed, language: .traditional, repository: true).key, "Changed source text must invalidate translation")
        let article = ArticleTranslationRequest(item: item, language: .traditional, repository: false)
        precondition(article.record(responses: ["excerpt": "說明"]) == nil, "Article titles must also be translated")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ArticleTranslationCache(directory: root)
        let record = TranslatedArticle(title: "owner/repository", excerpt: "英文說明")
        try! cache.save(record, key: request.key)
        precondition(cache.load(request.key) == record && cache.load(simplified.key) == nil)
        print("PASS language resolution, Chinese catalog, unchanged identifiers, complete replies and translation cache isolation")
    }
}
