import Foundation
import CryptoKit

struct ArticleTranslationRequest {
    let item: RadioItem
    let language: RadioLanguage
    let repository: Bool
    var key: String {
        let fields = [item.id, item.title, item.excerpt, language.resolved().rawValue, repository ? "repository" : "article"]
        let data = try! JSONEncoder().encode(fields)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    var parts: [String: String] {
        var result: [String: String] = [:]
        if !repository && !item.title.isEmpty { result["title"] = item.title }
        if !item.excerpt.isEmpty { result["excerpt"] = item.excerpt }
        return result
    }
    func record(responses: [String: String]) -> TranslatedArticle? {
        guard parts.keys.allSatisfy({ !(responses[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
        return TranslatedArticle(title: repository ? item.title : (responses["title"] ?? item.title), excerpt: responses["excerpt"] ?? item.excerpt)
    }
}
struct TranslatedArticle: Codable, Equatable {
    let title: String
    let excerpt: String
}
struct ArticleTranslationCache {
    let directory: URL
    func load(_ key: String) -> TranslatedArticle? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(key + ".json")) else { return nil }
        return try? JSONDecoder().decode(TranslatedArticle.self, from: data)
    }
    func save(_ value: TranslatedArticle, key: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent(key + ".json"), options: .atomic)
    }
    static var local: ArticleTranslationCache {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return Self(directory: root.appendingPathComponent("Little Radio/Translations"))
    }
}
