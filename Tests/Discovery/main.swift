import Foundation

@main struct DiscoveryTests {
    static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        precondition(condition(), name); print("PASS discovery: " + name)
    }
    static let rss = Data("<rss version='2.0'><channel><title>Physics updates</title><item><title>A finding</title><link>https://example.test/a</link></item></channel></rss>".utf8)
    static let atom = Data("<feed xmlns='http://www.w3.org/2005/Atom'><title>Lab notes</title></feed>".utf8)
    static func main() async throws {
        check(try! FeedDiscovery.websiteURL("example.test/blog").absoluteString == "https://example.test/blog", "bare website gets HTTPS")
        check(try! FeedDiscovery.websiteURL("http://example.test/").scheme == "https", "HTTP input upgrades to HTTPS")
        for bad in ["file:///etc/passwd", "javascript:alert(1)", "https://name:password@example.test", "not a website"] {
            do { _ = try FeedDiscovery.websiteURL(bad); fatalError("accepted unsafe input") } catch { print("PASS discovery: rejects invalid input") }
        }
        let direct = try await FeedDiscovery(loader: { url in DiscoveryPage(data: rss, url: url) }).discover("https://example.test/feed")
        check(direct.count == 1 && direct[0].title == "Physics updates", "direct RSS links still work")
        let emptyAtom = try await FeedDiscovery(loader: { url in DiscoveryPage(data: atom, url: url) }).discover("https://example.test/atom.xml")
        check(emptyAtom[0].title == "Lab notes", "empty valid Atom feeds are discoverable")
        let html = Data("""
        <html><head><base href='/journal/'><link title='Physics &amp; AI' href='updates.xml?a=1&amp;b=2' TYPE='application/rss+xml' REL='alternate'>
        <link rel=alternate type=application/atom+xml href='https://feeds.example.test/atom.xml'>
        <link rel='alternate' type='application/rss+xml' href='updates.xml?a=1&amp;b=2'>
        <link rel='alternate' type='application/rss+xml' href='javascript:bad'>
        <link rel='alternate' type='application/rss+xml' href='/broken.xml'></head><body>Home</body></html>
        """.utf8)
        let discovered = try await FeedDiscovery(loader: { url in
            if url.host == "start.example.test" { return DiscoveryPage(data: html, url: URL(string: "https://example.test/redirected/")!) }
            if url.absoluteString == "https://example.test/journal/updates.xml?a=1&b=2" { return DiscoveryPage(data: rss, url: url) }
            if url.absoluteString == "https://feeds.example.test/atom.xml" { return DiscoveryPage(data: atom, url: url) }
            return DiscoveryPage(data: Data("<html><title>Not a feed</title></html>".utf8), url: url)
        }).discover("https://start.example.test/blog")
        check(discovered.count == 2, "advertised RSS/Atom feeds validated and duplicate URLs removed")
        check(discovered[0].url.absoluteString == "https://example.test/journal/updates.xml?a=1&b=2", "redirect, relative base and entities resolved")
        check(discovered[0].title == "Physics updates" && discovered[1].title == "Lab notes", "publisher feed names retained in stable order")
        let fallback = try await FeedDiscovery(loader: { url in
            DiscoveryPage(data: url.absoluteString == "https://example.test/feed/" ? rss : Data("<html><body>Blog</body></html>".utf8), url: url)
        }).discover("https://example.test")
        check(fallback.count == 1 && fallback[0].url.absoluteString == "https://example.test/feed/", "common feed path fallback")
        let linked = try await FeedDiscovery(loader: { url in
            DiscoveryPage(data: url.path == "/blog-feed" ? rss : Data("<html><body><a href='/blog-feed'>RSS updates</a></body></html>".utf8), url: url)
        }).discover("https://example.test")
        check(linked.first?.url.path == "/blog-feed", "visible RSS link fallback")
        let newsPage = Data("""
        <html><head><title>Lab journal</title></head><body><main>
        <article><h2><a href="/news/first-finding">A new physics finding</a></h2><time datetime="2026-10-14"></time><p>A publisher-written excerpt.</p></article>
        <article><a href="/news/second-finding"><h2>Another physics finding</h2></a><time datetime="2026-10-15"></time></article>
        </main></body></html>
        """.utf8)
        do {
            let pageSource = try await FeedDiscovery(loader: { url in
                guard url.path == "/news" else { throw FeedError.message("404") }
                return DiscoveryPage(data: newsPage, url: url)
            }).discover("https://example.test/news")
            check(pageSource.first?.url.path == "/news" && pageSource.first?.title == "Lab journal", "website without RSS becomes a readable page source")
        } catch { fatalError("No-RSS page with article cards must remain usable: \(error)") }
        do {
            _ = try await FeedDiscovery(loader: { url in DiscoveryPage(data: Data("<html><body>No feed</body></html>".utf8), url: url) }).discover("https://example.test")
            fatalError("ordinary HTML saved as feed")
        } catch { print("PASS discovery: no feed is a visible failure, never a saved homepage") }
        do {
            _ = try await FeedDiscovery(loader: { url in DiscoveryPage(data: rss, url: URL(string: "http://example.test/feed")!) }).discover("https://example.test")
            fatalError("insecure redirect accepted")
        } catch { print("PASS discovery: rejects insecure final URLs") }
        let task = Task { try await FeedDiscovery(loader: { _ in throw CancellationError() }).discover("https://example.test") }
        do { _ = try await task.value; fatalError("cancelled discovery succeeded") } catch is CancellationError { print("PASS discovery: cancellation propagates") }
        if CommandLine.arguments.contains("--live") {
            let result = try await FeedDiscovery().discover("https://www.sciencedaily.com/news/matter_energy/physics/")
            check(!result.isEmpty, "live normal ScienceDaily page resolves to feed")
            print("LIVE DISCOVERY: " + result.map { $0.title + " → " + $0.url.absoluteString }.joined(separator: " | "))
        }
    }
}
