import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Reads publisher metadata and article cards from public HTML. No script execution or article crawling.
enum WebpageReader {
    struct Result { let title: String; let items: [RadioItem]; let usesPageOrder: Bool }
    static let unavailable = "No readable articles found. Try the site's news or blog page. Pages requiring JavaScript or a login may not work yet."

    static func parse(_ data: Data, pageURL: URL, source: String) throws -> Result {
        guard data.count <= 4_000_000, let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
              let document = try? XMLDocument(xmlString: normalizedHTML(html), options: [.documentTidyHTML, .nodeLoadExternalEntitiesNever]) else {
            throw FeedError.message(unavailable)
        }
        func nodes(_ path: String, in node: XMLNode) -> [XMLNode] { (try? node.nodes(forXPath: path)) ?? [] }
        func attr(_ name: String, _ node: XMLNode) -> String? { (node as? XMLElement)?.attribute(forName: name)?.stringValue }
        func clean(_ node: XMLNode?) -> String { FeedParser.clean(node?.stringValue ?? "") }
        var linkBase = pageURL
        func safeURL(_ raw: String) -> URL? {
            guard !raw.hasPrefix("#"), let url = URL(string: FeedParser.clean(raw), relativeTo: linkBase)?.absoluteURL,
                  url.scheme == "https", url.user == nil, url.password == nil,
                  url.host?.lowercased().replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression) == pageURL.host?.lowercased().replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression),
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
            components.host = pageURL.host
            components.fragment = nil
            components.queryItems = components.queryItems?.filter { !$0.name.lowercased().hasPrefix("utm_") && !["fbclid", "gclid"].contains($0.name.lowercased()) }
            if components.queryItems?.isEmpty == true { components.queryItems = nil }
            return components.url
        }
        if let base = nodes("//base", in: document).first.flatMap({ attr("href", $0) }), let resolved = safeURL(base) { linkBase = resolved }
        let title = String(clean(nodes("//title", in: document).first).prefix(120))
        var items: [RadioItem] = []
        func append(title rawTitle: String, url rawURL: String, excerpt: String = "", date: String? = nil) {
            let title = FeedParser.clean(rawTitle)
            guard (6...300).contains(title.count), let url = safeURL(rawURL),
                  !["read more", "learn more", "latest news", "all articles", "view all"].contains(title.lowercased()) else { return }
            let item = RadioItem(id: url.absoluteString, title: title, excerpt: String(FeedParser.clean(excerpt).prefix(340)), source: source, url: url, publishedAt: date.flatMap(parseDate), metric: nil)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                let old = items[index]
                items[index] = RadioItem(id: old.id, title: old.title, excerpt: old.excerpt.isEmpty ? item.excerpt : old.excerpt, source: source, url: old.url, publishedAt: old.publishedAt ?? item.publishedAt, metric: nil)
            } else { items.append(item) }
        }
        // Reuse an existing publisher adapter for its compact list rows as well as cards.
        if ["anthropic.com", "www.anthropic.com"].contains(pageURL.host ?? ""), pageURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "news",
           let newsroom = try? AnthropicNews.parse(data, source: source) {
            for item in newsroom { append(title: item.title, url: item.url.absoluteString, excerpt: item.excerpt, date: item.publishedAt.map { ISO8601DateFormatter().string(from: $0) }) }
        }
        // Only article types qualify; breadcrumb, product and organization metadata do not.
        func visit(_ value: Any, depth: Int = 0) {
            guard depth < 20, items.count < 100 else { return }
            if let list = value as? [Any] { for child in list { visit(child, depth: depth + 1) }; return }
            guard let object = value as? [String: Any] else { return }
            let types = (object["@type"] as? [String]) ?? [object["@type"] as? String ?? ""]
            if types.contains(where: { ["Article", "NewsArticle", "BlogPosting", "TechArticle", "Report", "ScholarlyArticle"].contains($0.components(separatedBy: "/").last ?? $0) }) {
                let main = object["mainEntityOfPage"]
                let address = object["url"] as? String ?? (main as? String) ?? (main as? [String: Any])?["@id"] as? String ?? object["@id"] as? String
                if let address { append(title: object["headline"] as? String ?? object["name"] as? String ?? "", url: address, excerpt: object["description"] as? String ?? "", date: object["datePublished"] as? String) }
            }
            // Traversal of dictionaries is stable; arrays preserve the publisher's ordering.
            for key in object.keys.sorted() where !["@context", "author", "publisher", "image"].contains(key) {
                if let child = object[key], child is [Any] || child is [String: Any] { visit(child, depth: depth + 1) }
            }
        }
        let jsonPattern = #"(?is)<script\b[^>]*\btype\s*=\s*(?:"application/ld\+json"|'application/ld\+json'|application/ld\+json)[^>]*>(.*?)</script>"#
        if let regex = try? NSRegularExpression(pattern: jsonPattern) {
            for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
                if let range = Range(match.range(at: 1), in: html), let bytes = String(html[range]).data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: bytes) { visit(json) }
            }
        }
        let article = "div[@data-lr-tag='article']"
        for node in nodes("//div[@data-lr-tag='nav' or @data-lr-tag='footer' or @data-lr-tag='aside'] | //div[@data-lr-tag='header' and not(ancestor::div[@data-lr-tag='article'])] | //noscript | //*[@hidden or @data-lr-hidden='true' or @aria-hidden='true']", in: document) { node.detach() }
        let region = nodes("//div[@data-lr-tag='main']", in: document).first ?? nodes("//body", in: document).first ?? document
        let candidates = nodes(".//" + article + " | .//a[.//h2 or .//h3 or .//h4] | .//h2/a | .//h3/a | .//h4/a", in: region)
        for candidate in candidates.prefix(300) {
            let isArticle = attr("data-lr-tag", candidate) == "article"
            let anchor = isArticle ? (nodes(".//h1/a | .//h2/a | .//h3/a | .//a[.//h1 or .//h2 or .//h3]", in: candidate).first ?? nodes(".//a[@href]", in: candidate).first) : candidate
            guard let anchor, let href = attr("href", anchor), let url = safeURL(href) else { continue }
            // A section heading such as /news is not an article card by itself.
            let articlePath = url.path.range(of: "(?i)/(news|blog|blogs|articles?|posts?|journal|updates?|press|stories|research)/[^/]+|/[12][0-9]{3}/", options: .regularExpression) != nil
            guard isArticle || articlePath else { continue }
            let heading = nodes(".//h1 | .//h2 | .//h3 | .//h4", in: anchor).first
            let scope = isArticle ? candidate : (nodes("ancestor::" + article + "[1]", in: anchor).first ?? anchor)
            let time = nodes(".//span[@data-lr-tag='time']", in: scope).first
            let date = time.flatMap { attr("datetime", $0) } ?? time?.stringValue
            append(title: clean(heading ?? anchor), url: href, excerpt: clean(nodes(".//p", in: scope).first), date: date)
        }
        guard !items.isEmpty else { throw FeedError.message(unavailable) }
        let pageOrder = items.contains { $0.publishedAt == nil }
        if !pageOrder { items.sort { $0.publishedAt! > $1.publishedAt! } }
        let metric = pageOrder ? "Website · Page order" : "Website · Dated articles"
        let labelled = items.prefix(30).map { RadioItem(id: $0.id, title: $0.title, excerpt: $0.excerpt, source: $0.source, url: $0.url, publishedAt: $0.publishedAt, metric: metric) }
        return Result(title: title.isEmpty ? (pageURL.host ?? "Website") : title, items: labelled, usesPageOrder: pageOrder)
    }

    // Foundation's HTML4 tidy pass drops unknown HTML5 tags. Preserve their semantics
    // using supported containers before parsing. Scripts are read only as JSON above.
    private static func normalizedHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "(?is)<!--.*?-->|<(script|style)\\b[^>]*>.*?</\\1>", with: "", options: .regularExpression)
        let pattern = "(?is)<(/?)(article|main|nav|header|footer|aside|time|section)\\b([^>]*)>"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                guard let range = Range(match.range, in: text), let tagRange = Range(match.range(at: 2), in: text), let attrRange = Range(match.range(at: 3), in: text) else { continue }
                let tag = String(text[tagRange]).lowercased(), attributes = String(text[attrRange])
                let container = tag == "time" ? "span" : "div"
                let content = tag == "time" ? "&#xfeff;" : ""
                let closing = match.range(at: 1).length > 0
                let hidden = attributes.range(of: "(?i)(?:^|\\s)hidden(?:\\s|=|$)", options: .regularExpression) != nil ? " data-lr-hidden=\"true\"" : ""
                text.replaceSubrange(range, with: closing ? "</\(container)>" : "<\(container) data-lr-tag=\"\(tag)\"\(hidden)\(attributes)>\(content)")
            }
        }
        return text
    }

    private static func parseDate(_ value: String) -> Date? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = FeedParser.date(text) { return date }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["MMM d, yyyy", "MMMM d, yyyy", "d MMM yyyy", "d MMMM yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
