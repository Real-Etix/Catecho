import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum SourceKind: String, Codable { case feed, webpage }

struct DiscoveredFeed: Identifiable, Equatable {
    let url: URL
    let title: String
    var kind: SourceKind = .feed
    var id: String { url.absoluteString }
}
struct DiscoveryPage { let data: Data; let url: URL }

/// Prefers verified feeds; offers readable article pages as an explicitly different source kind.
struct FeedDiscovery {
    typealias Loader = (URL) async throws -> DiscoveryPage
    private let loader: Loader
    init(loader: @escaping Loader = FeedDiscovery.download) { self.loader = loader }

    static func websiteURL(_ input: String) throws -> URL {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 4096, !text.contains(where: { $0.isWhitespace }) else { throw invalidLink }
        let hasScheme = text.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil
        guard var parts = URLComponents(string: hasScheme ? text : "https://" + text),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, host.contains("."), !host.hasPrefix("."),
              parts.user == nil, parts.password == nil else { throw invalidLink }
        parts.scheme = "https"; parts.fragment = nil
        if parts.port == 80 { parts.port = nil }
        guard let url = parts.url else { throw invalidLink }
        return url
    }
    private static var invalidLink: FeedError { .message("Paste a website link such as example.com, or a feed link.") }

    func discover(_ input: String) async throws -> [DiscoveredFeed] {
        try Task.checkCancellation()
        let initial = try Self.websiteURL(input)
        let page = try await load(initial)
        if let feed = verifiedFeed(page) { return [feed] }
        guard let html = String(data: page.data, encoding: .utf8) ?? String(data: page.data, encoding: .isoLatin1) else {
            throw FeedError.message("This website could not be read. Try its blog or news page.")
        }
        let advertised = advertisedLinks(html, pageURL: page.url)
        let found = try await verify(advertised)
        if !found.isEmpty { return found }
        // A bounded fallback for publishers without feed autodiscovery markup.
        var root = URLComponents(url: page.url, resolvingAgainstBaseURL: true)!
        root.path = "/"; root.query = nil; root.fragment = nil
        let paths = ["feed/", "rss.xml", "atom.xml", "feed.xml"]
        var candidates = paths.compactMap { URL(string: $0, relativeTo: root.url!)?.absoluteURL }
        if page.url.path != "" && page.url.path != "/" {
            var directory = URLComponents(url: page.url, resolvingAgainstBaseURL: true)!
            directory.query = nil; directory.fragment = nil
            if !directory.path.hasSuffix("/") { directory.path += "/" }
            if let url = directory.url?.appendingPathComponent("feed/") { candidates.insert(url, at: 0) }
        }
        candidates.removeAll { advertised.contains($0) || $0 == page.url }
        let fallback = try await verify(candidates)
        if !fallback.isEmpty { return fallback }
        try Task.checkCancellation()
        let articles = try WebpageReader.parse(page.data, pageURL: page.url, source: page.url.host ?? "Website")
        return [DiscoveredFeed(url: page.url, title: articles.title, kind: .webpage)]
    }

    private func load(_ url: URL) async throws -> DiscoveryPage {
        try Task.checkCancellation()
        let page = try await loader(url)
        try Task.checkCancellation()
        guard page.url.scheme?.lowercased() == "https", page.url.user == nil, page.url.password == nil, page.url.host != nil else {
            throw FeedError.message("The website redirected to an unsupported address.")
        }
        guard !page.data.isEmpty, page.data.count <= 4_000_000 else { throw FeedError.message("This website returned an empty or unusually large page.") }
        return page
    }

    private func verifiedFeed(_ page: DiscoveryPage) -> DiscoveredFeed? {
        let identity = FeedIdentity()
        let parser = XMLParser(data: page.data)
        parser.shouldResolveExternalEntities = false; parser.delegate = identity
        guard parser.parse(), identity.isFeed else { return nil }
        let title = FeedParser.clean(identity.title)
        return DiscoveredFeed(url: page.url, title: title.isEmpty ? (page.url.host ?? "Feed") : String(title.prefix(120)))
    }

    private func verify(_ candidates: [URL]) async throws -> [DiscoveredFeed] {
        var seen = Set<String>()
        let bounded = candidates.filter { seen.insert($0.absoluteString).inserted }.prefix(6)
        let indexed = try await withThrowingTaskGroup(of: (Int, DiscoveredFeed?).self) { group in
            for (index, url) in bounded.enumerated() {
                group.addTask {
                    do { return (index, verifiedFeed(try await load(url))) }
                    catch is CancellationError { throw CancellationError() }
                    catch { try Task.checkCancellation(); return (index, nil) }
                }
            }
            var results: [(Int, DiscoveredFeed)] = []
            for try await (index, feed) in group { if let feed { results.append((index, feed)) } }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        try Task.checkCancellation()
        var finalURLs = Set<String>()
        return indexed.filter { finalURLs.insert($0.id).inserted }
    }

    private func advertisedLinks(_ html: String, pageURL: URL) -> [URL] {
        let page = html.replacingOccurrences(of: "(?is)<!--.*?-->|<(script|style)\\b[^>]*>.*?</\\1>", with: "", options: .regularExpression)
        let bases = Self.matches("(?is)<base\\b([^>]*)>", page)
        let base = bases.first.flatMap { Self.attributes($0[1])["href"] }.flatMap { safeURL($0, relativeTo: pageURL) } ?? pageURL
        var urls: [URL] = []
        for tag in Self.matches("(?is)<link\\b([^>]*)>", page) {
            let attrs = Self.attributes(tag[1])
            let type = (attrs["type"] ?? "").lowercased().split(separator: ";").first.map(String.init) ?? ""
            let rel = (attrs["rel"] ?? "").lowercased().split(whereSeparator: { $0.isWhitespace })
            if rel.contains("alternate"), ["application/rss+xml", "application/atom+xml", "application/rdf+xml"].contains(type),
               let href = attrs["href"], let url = safeURL(href, relativeTo: base) { urls.append(url) }
        }
        if urls.isEmpty {
            for anchor in Self.matches("(?is)<a\\b([^>]*)>(.*?)</a>", page) {
                let text = FeedParser.clean(anchor[2])
                guard text.range(of: "(?i)\\b(rss|atom|feeds?)\\b|订阅|訂閱", options: .regularExpression) != nil,
                      let href = Self.attributes(anchor[1])["href"], let url = safeURL(href, relativeTo: base) else { continue }
                urls.append(url)
            }
        }
        var seen = Set<String>()
        return Array(urls.filter { seen.insert($0.absoluteString).inserted }.prefix(6))
    }
    private func safeURL(_ href: String, relativeTo base: URL) -> URL? {
        guard let resolved = URL(string: FeedParser.clean(href), relativeTo: base)?.absoluteURL,
              ["https", "http"].contains(resolved.scheme?.lowercased() ?? "") else { return nil }
        return try? Self.websiteURL(resolved.absoluteString)
    }
    private static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (0..<match.numberOfRanges).map { Range(match.range(at: $0), in: text).map { String(text[$0]) } ?? "" }
        }
    }
    private static func attributes(_ tag: String) -> [String: String] {
        var values: [String: String] = [:]
        let pattern = #"([A-Za-z_:][A-Za-z0-9_:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))"#
        for match in matches(pattern, tag) {
            let key = match[1].lowercased()
            if values[key] == nil { values[key] = match.dropFirst(2).first { !$0.isEmpty } ?? "" }
        }
        return values
    }
    static func download(_ url: URL) async throws -> DiscoveryPage {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8; config.timeoutIntervalForResource = 12
        let session = URLSession(configuration: config, delegate: SecureFeedRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("Catecho/1.0 (macOS; feed discovery)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html, application/rss+xml, application/atom+xml, application/xml, */*;q=0.5", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let finalURL = http.url else {
                throw FeedError.message("Could not reach this website. Check the link or try again.")
            }
            return DiscoveryPage(data: data, url: finalURL)
        } catch {
            try Task.checkCancellation()
            throw FeedError.message("Could not reach this website. Check the link or try again.")
        }
    }
}

private final class SecureFeedRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let url = request.url
        completionHandler(url?.scheme == "https" && url?.user == nil && url?.password == nil ? request : nil)
    }
}

private final class FeedIdentity: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var root = ""
    private var hasChannel = false
    private var collectingTitle = false
    var title = ""
    var isFeed: Bool { root == "feed" || (["rss", "rdf"].contains(root) && hasChannel) }
    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let name = element.lowercased().split(separator: ":").last.map(String.init) ?? element
        path.append(name)
        if path.count == 1 { root = name }
        if path.count == 2 && name == "channel" { hasChannel = true }
        if title.isEmpty && (path == ["feed", "title"] || path == [root, "channel", "title"]) { collectingTitle = true }
    }
    func parser(_ parser: XMLParser, foundCharacters text: String) { if collectingTitle { title += text } }
    func parser(_ parser: XMLParser, foundCDATA data: Data) { if let text = String(data: data, encoding: .utf8) { self.parser(parser, foundCharacters: text) } }
    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        if path.last == "title" { collectingTitle = false }
        if !path.isEmpty { path.removeLast() }
    }
}
