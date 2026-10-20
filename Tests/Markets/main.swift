import Foundation

@main
struct MarketTests {
    static let now = Date(timeIntervalSince1970: 1_790_000_000)
    static func quote(_ symbol: String = "AAPL", currency: String = "USD", time: Double = 1_789_999_000, price: Double? = 123.45, percent: Double? = -1.2) throws -> Data {
        var meta: [String: Any] = ["symbol": symbol, "currency": currency, "regularMarketTime": time, "chartPreviousClose": 50]
        meta["regularMarketPrice"] = price; meta["regularMarketChangePercent"] = percent
        return try JSONSerialization.data(withJSONObject: ["chart": ["result": [["meta": meta]]]])
    }
    static func row(_ id: String, time: Date, kind: String = "regular", author: String = "thsottiaux", url: String? = nil) -> [String: Any] {
        ["id": id, "reset_type": kind, "announced_at": ISO8601DateFormatter().string(from: time),
         "text": "A public reset announcement", "source": ["type": "x_post", "author": author,
         "url": url ?? "https://x.com/thsottiaux/status/\(id)"]]
    }
    static func resets(_ rows: [[String: Any]]) throws -> FeedBatch {
        try ResetAnnouncements.parse(JSONSerialization.data(withJSONObject: ["data": rows]), now: now)
    }
    static func rejects(_ action: () throws -> Void) {
        do { try action(); fatalError("Expected invalid input to fail") } catch {}
    }
    static func main() async throws {
        for id in ["finance", "stocks", "resets"] {
            precondition(StationCatalog.presets.contains(RadioChannel(rawValue: id)!), "Missing requested station: \(id)")
        }
        print("PASS finance, stocks and reset stations are selectable")
        let legacy = try JSONDecoder().decode(FeedConfiguration.self, from: Data("{}".utf8))
        precondition(legacy.stockSymbols.isEmpty && !legacy.resetAlerts && legacy.enabledChannels == ["ai", "github", "research"])
        let symbols = try StockSymbols.parse(" aapl, MSFT\nAAPL，brk.b ")
        precondition(symbols == ["AAPL", "MSFT", "BRK.B"])
        rejects { _ = try StockSymbols.parse("https://example.com") }
        rejects { _ = try StockSymbols.normalize((0..<21).map { "A\($0)" }) }
        print("PASS old settings migrate quietly; watchlists validate, normalize and deduplicate")
        let parsed = try StockQuote.parse(quote(), symbol: "AAPL", now: now)
        precondition(parsed.price == 123.45 && parsed.changePercent == -1.2 && parsed.asOf == now.addingTimeInterval(-1000))
        let noChange = try StockQuote.parse(quote(percent: nil), symbol: "AAPL", now: now)
        precondition(noChange.changePercent == nil, "Never substitute range previous-close for daily change")
        rejects { _ = try StockQuote.parse(quote(currency: "CAD"), symbol: "AAPL", now: now) }
        rejects { _ = try StockQuote.parse(quote(), symbol: "MSFT", now: now) }
        rejects { _ = try StockQuote.parse(quote(time: 1_790_001_000), symbol: "AAPL", now: now) }
        rejects { _ = try StockQuote.parse(quote(price: nil), symbol: "AAPL", now: now) }
        rejects { _ = try StockQuote.parse(quote(price: 0), symbol: "AAPL", now: now) }
        print("PASS quote validation preserves provider time and regular-session change")
        var config = FeedConfiguration(); config.stockSymbols = ["MSFT", "AAPL", "BAD"]
        let service = FeedService { url in
            if url.host == "query1.finance.yahoo.com" {
                if url.lastPathComponent == "BAD" { throw FeedError.message("Unavailable fixture") }
                return try quote(url.lastPathComponent)
            }
            return Data("<rss><channel><item><title>Market story</title><link>https://example.com/story</link></item></channel></rss>".utf8)
        }
        let batch = try await service.fetch(channel: .stocks, configuration: config)
        precondition(batch.items.prefix(3).map(\.id) == ["quote:MSFT", "quote:AAPL", "quote:BAD"])
        precondition(batch.items[2].stockQuote?.price == nil && batch.items.count == 4 && batch.warning?.contains("BAD") == true)
        let broken = FeedService { _ in throw FeedError.message("Offline fixture") }
        do { _ = try await broken.fetch(channel: .stocks, configuration: config); fatalError("All sources failed") } catch {}
        print("PASS partial quotes stay in watchlist order with headlines; total failure retains cache")
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = RadioCache(directory: cacheDir)
        try cache.save(batch, channel: .stocks, configuration: config)
        config.stockSymbols.reverse()
        precondition(cache.load(channel: .stocks, configuration: config) == nil)
        var legacyItem = try JSONSerialization.jsonObject(with: JSONEncoder().encode(parsed.item)) as! [String: Any]
        legacyItem.removeValue(forKey: "stockQuote")
        let oldItem = try JSONDecoder().decode(RadioItem.self, from: JSONSerialization.data(withJSONObject: legacyItem))
        precondition(oldItem.stockQuote == nil)
        print("PASS quote cache isolates watchlist order; older item caches decode")
        let baselineRow = row("100", time: now.addingTimeInterval(-3600))
        let newRow = row("101", time: now.addingTimeInterval(-60), kind: "banked")
        let baseline = try resets([baselineRow])
        let validated = try resets([baselineRow, baselineRow, newRow,
            row("102", time: now, author: "someone"), row("103", time: now, kind: "rumor"),
            row("104", time: now, url: "https://x.com.evil.example/thsottiaux/status/104"),
            row("105", time: now, url: "https://x.com/thsottiaux/status/999"),
            row("106", time: now.addingTimeInterval(10))])
        precondition(validated.items.count == 2 && validated.items.first?.metric == "BANKED RESET" && validated.warning != nil)
        rejects { _ = try resets([row("1", time: now, author: "someone")]) }
        let empty = try resets([])
        precondition(empty.items.isEmpty)
        let observed = try resets([["source": ["type": "observed"]]])
        precondition(observed.items.isEmpty && observed.warning == nil)
        rejects { _ = try ResetAnnouncements.parse(Data("{}".utf8)) }
        print("PASS reset parser validates author, original URL, type, dates and duplicate IDs")
        var ledger = ResetAlertLedger()
        precondition(ledger.consume([], now: now).isEmpty)
        precondition(ledger.consume(baseline.items, now: now).isEmpty)
        precondition(ledger.consume(validated.items, now: now).map(\.id) == ["reset:101"])
        precondition(ledger.consume(validated.items, now: now).isEmpty)
        var restored = try JSONDecoder().decode(ResetAlertLedger.self, from: JSONEncoder().encode(ledger))
        precondition(restored.consume(validated.items, now: now).isEmpty)
        let backfill = try resets([row("99", time: now.addingTimeInterval(-2000))])
        precondition(restored.consume(backfill.items, now: now).isEmpty)
        let sameInstant = try resets([row("109", time: now.addingTimeInterval(-60))])
        precondition(restored.consume(sameInstant.items, now: now).isEmpty, "Equal-timestamp backfills must stay quiet")
        let tooLate = try resets([row("110", time: now)])
        precondition(restored.consume(tooLate.items, now: now.addingTimeInterval(90000)).isEmpty)
        print("PASS alert baseline is quiet; new posts alert once across restarts, backfills and stale polls")
    }
}
