import Foundation

@main struct WebpageTests {
    static func check(_ condition: @autoclosure () -> Bool, _ name: String) { precondition(condition(), name); print("PASS webpage: " + name) }
    static let url = URL(string: "https://lab.example.test/news")!
    static let cards = Data("""
    <html><head><meta charset="utf-8"><title>物理研究與 AI</title></head><body>
    <nav><a href="/news/navigation"><h2>Navigation must be ignored</h2></a></nav>
    <main><article><header><h2><a href="/news/older?utm_source=mail#top">Older physics discovery</a></h2><time datetime="2026-10-14"></time></header><p>Exact publisher summary.</p></article>
    <article><a href="/news/newer"><h2>Latest physics discovery</h2></a><time datetime="2026-10-15"></time></article>
    <a href="/news"><h2>All articles</h2></a><a href="javascript:alert(1)"><h2>Unsafe script story</h2></a>
    <a href="https://other.example.test/news/foreign"><h2>External link not a story</h2></a>
    <article hidden><h2><a href="/news/hidden">A hidden template story</a></h2></article>
    </main></body></html>
    """.utf8)
    static func main() async throws {
        let parsed = try WebpageReader.parse(cards, pageURL: url, source: "Lab")
        check(parsed.title == "物理研究與 AI", "Unicode site title retained")
        check(parsed.items.count == 2 && parsed.items.first?.url.path == "/news/newer", "dated cards sorted newest first, navigation and unsafe links excluded")
        check(parsed.items.last?.url.absoluteString == "https://lab.example.test/news/older" && parsed.items.last?.excerpt == "Exact publisher summary.", "article headers, relative URLs, tracking removal and real excerpts")
        check(parsed.items.first?.excerpt == "" && parsed.items.first?.metric == "Website · Dated articles", "missing summary stays empty and method labelled")
        let undated = Data("<main><a href='/news/first'><h2>First publisher choice</h2></a><article><h2><a href='/news/second'>Dated second choice</a></h2><time datetime='2026-10-16'></time></article></main>".utf8)
        let ordered = try WebpageReader.parse(undated, pageURL: url, source: "Lab")
        check(ordered.usesPageOrder && ordered.items.first?.url.path == "/news/first" && ordered.items.first?.publishedAt == nil, "mixed dates retain publisher order without invented dates")
        let basePage = Data("<html><head><base href='/journal/'></head><body><main><a href='posts/finding'><h2>Base-relative science finding</h2></a><a href='/products/features'><h2>Browse all product features</h2></a></main></body></html>".utf8)
        let baseResult = try WebpageReader.parse(basePage, pageURL: url, source: "Lab")
        check(baseResult.items.count == 1 && baseResult.items[0].url.path == "/journal/posts/finding", "HTML base resolved and marketing headings excluded")
        let structured = Data("""
        <html><head><script type="application/ld+json">{"@graph":[{"@type":"BreadcrumbList","itemListElement":[{"name":"Not an article","url":"/category"}]},{"@type":"NewsArticle","headline":"A structured discovery","mainEntityOfPage":{"@id":"/news/structured"},"datePublished":"2026-10-16T00:00:00Z","description":"Published &amp; verified."}]}</script></head>
        <body><article><h2><a href='/news/structured'>A structured discovery</a></h2></article></body></html>
        """.utf8)
        let json = try WebpageReader.parse(structured, pageURL: url, source: "Lab")
        check(json.items.count == 1 && json.items[0].excerpt == "Published & verified." && json.items[0].publishedAt != nil, "JSON-LD articles merge with cards; breadcrumbs excluded")
        do { _ = try WebpageReader.parse(Data("<html><body><nav><a href='/login'>Login</a></nav><script>renderArticles()</script></body></html>".utf8), pageURL: url, source: "Lab"); fatalError("empty page accepted") } catch { print("PASS webpage: unreadable page is actionable failure, never false success") }
        let old = Data("{\"id\":\"lab\",\"title\":\"Lab\",\"feedURLs\":[\"https://lab.example.test/feed\"],\"keywords\":\"\",\"enabled\":true}".utf8)
        let legacy = try JSONDecoder().decode(CustomStation.self, from: old)
        check(legacy.webpageURLs.isEmpty && legacy.feedURLs.count == 1, "existing saved stations decode unchanged")
        let station = CustomStation(id: "lab", title: "Lab", feedURLs: [], webpageURLs: [url.absoluteString])
        check(try! JSONDecoder().decode(CustomStation.self, from: JSONEncoder().encode(station)) == station, "webpage source type survives save and reload")
        var config = FeedConfiguration(); config.customStations = [station]
        let service = FeedService(downloader: { _ in undated })
        let batch = try await service.fetch(channel: .station("lab"), configuration: config)
        check(batch.items.count == 2 && batch.items.first?.url.path == "/news/first", "refresh routes webpage to HTML reader and preserves page order")
        config.customStations[0].keywords = "second"
        let filtered = try await service.fetch(channel: .station("lab"), configuration: config)
        check(filtered.items.count == 1 && filtered.items[0].url.path == "/news/second", "custom keyword filter also applies to webpage sources")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = RadioCache(directory: directory)
        try cache.save(batch, channel: .station("lab"), configuration: config)
        check(cache.load(channel: .station("lab"), configuration: config)?.items.count == 2, "webpage edition cached")
        config.customStations[0].webpageURLs = ["https://lab.example.test/other"]
        check(cache.load(channel: .station("lab"), configuration: config) == nil, "changing webpage cannot reuse wrong cached edition")
        if CommandLine.arguments.contains("--live") {
            let found = try await FeedDiscovery().discover("https://www.anthropic.com/news")
            check(found.first?.kind == .webpage, "live Anthropic page offered without requiring RSS")
            var live = FeedConfiguration(); live.customStations = [CustomStation(id: "live", title: "Anthropic", feedURLs: [], webpageURLs: found.map { $0.url.absoluteString })]
            let edition = try await FeedService().fetch(channel: .station("live"), configuration: live)
            check(edition.items.count >= 3 && edition.items.allSatisfy { ["www.anthropic.com", "anthropic.com"].contains($0.url.host ?? "") }, "live webpage station refreshes article links")
            print("LIVE WEBPAGE: \(edition.items.count) articles; \(edition.items[0].title)")
        }
    }
}
