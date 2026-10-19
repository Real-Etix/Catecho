import Foundation

/// A small adapter for Anthropic's public newsroom, which does not advertise an RSS feed.
/// Treat an unrecognized page as a fetch failure so the model keeps its cached edition.
enum AnthropicNews {
    static func parse(_ data: Data, source: String) throws -> [RadioItem] {
        guard let html = String(data: data, encoding: .utf8) else {
            throw FeedError.message("Anthropic returned unreadable news.")
        }
        let page = html.replacingOccurrences(of: "(?is)<(script|style)\\b[^>]*>.*?</\\1>", with: "", options: .regularExpression)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        var articles: [String: RadioItem] = [:]
        for anchor in matches("(?is)<a\\b([^>]*)>(.*?)</a>", in: page) {
            guard let path = attribute("href", in: anchor[1]),
                  path.range(of: "^/news/[A-Za-z0-9-]+/?$", options: .regularExpression) != nil,
                  let url = URL(string: "https://www.anthropic.com" + path),
                  let time = matches("(?is)<time\\b([^>]*)>(.*?)</time>", in: anchor[2]).first else { continue }
            let date = attribute("datetime", in: time[1]).flatMap(FeedParser.date)
                ?? formatter.date(from: FeedParser.clean(time[2]))
            let heading = matches("(?is)<h[23]\\b[^>]*>(.*?)</h[23]>", in: anchor[2]).first?[1]
            let titleSpan = matches("(?is)<span\\b([^>]*)>(.*?)</span>", in: anchor[2]).first {
                attribute("class", in: $0[1])?.contains("__title") == true
            }?[2]
            let title = FeedParser.clean(heading ?? titleSpan ?? "")
            guard let date, !title.isEmpty else { continue }
            let excerpt = String(FeedParser.clean(matches("(?is)<p\\b[^>]*>(.*?)</p>", in: anchor[2]).first?[1] ?? "").prefix(340))
            let id = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            // Featured cards can have excerpts; the repeated list entry usually has none.
            if let existing = articles[id], !existing.excerpt.isEmpty { continue }
            articles[id] = RadioItem(id: id, title: title, excerpt: excerpt, source: source, url: url, publishedAt: date, metric: nil)
        }
        guard !articles.isEmpty else {
            throw FeedError.message("Anthropic's news page could not be read. Its layout may have changed.")
        }
        return articles.values.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    private static func attribute(_ name: String, in html: String) -> String? {
        matches("(?is)\\b" + name + "\\s*=\\s*[\"']([^\"']*)[\"']", in: html).first?[1]
    }
    private static func matches(_ pattern: String, in html: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).map { match in
            (0..<match.numberOfRanges).map { Range(match.range(at: $0), in: html).map { String(html[$0]) } ?? "" }
        }
    }
}
