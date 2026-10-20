import Foundation

enum StockSymbols {
    static func parse(_ input: String) throws -> [String] {
        try normalize(input.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，;；"))))
    }
    static func normalize(_ input: [String]) throws -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in input {
            let symbol = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if symbol.isEmpty { continue }
            guard symbol.range(of: "^[A-Z][A-Z0-9.-]{0,9}$", options: .regularExpression) != nil else {
                throw FeedError.message("Use US ticker symbols separated by commas.")
            }
            if seen.insert(symbol).inserted { result.append(symbol) }
        }
        guard result.count <= 20 else { throw FeedError.message("You can track up to 20 stocks.") }
        return result
    }
}

struct StockQuote: Codable, Equatable {
    let symbol: String
    let name: String
    let price: Double?
    let changePercent: Double?
    let asOf: Date?
    var isCached = false

    static func unavailable(_ symbol: String) -> Self {
        Self(symbol: symbol, name: symbol, price: nil, changePercent: nil, asOf: nil)
    }
    var item: RadioItem {
        RadioItem(id: "quote:" + symbol, title: symbol, excerpt: name, source: "Yahoo Finance",
                  url: URL(string: "https://finance.yahoo.com/quote/\(symbol)/")!,
                  publishedAt: asOf, metric: nil, stockQuote: self)
    }
    static func endpoint(_ symbol: String) -> URL {
        URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=5d")!
    }
    static func parse(_ data: Data, symbol: String, now: Date = Date()) throws -> Self {
        struct Envelope: Decodable {
            struct Chart: Decodable {
                struct Result: Decodable {
                    struct Meta: Decodable {
                        let symbol: String
                        let currency: String?
                        let shortName: String?
                        let longName: String?
                        let regularMarketPrice: Double?
                        let regularMarketChangePercent: Double?
                        let regularMarketTime: Double?
                    }
                    let meta: Meta
                }
                let result: [Result]?
            }
            let chart: Chart
        }
        guard let meta = try? JSONDecoder().decode(Envelope.self, from: data).chart.result?.first?.meta,
              meta.symbol.uppercased() == symbol, meta.currency == "USD",
              let price = meta.regularMarketPrice, price.isFinite, price > 0,
              let stamp = meta.regularMarketTime, stamp.isFinite, stamp > 0,
              stamp <= now.timeIntervalSince1970 + 300 else {
            throw FeedError.message("Quote unavailable: " + symbol)
        }
        // chartPreviousClose belongs to the requested range, not necessarily yesterday.
        let percent = meta.regularMarketChangePercent.flatMap { $0.isFinite ? $0 : nil }
        return Self(symbol: symbol, name: String((meta.shortName ?? meta.longName ?? symbol).prefix(100)),
                    price: price, changePercent: percent, asOf: Date(timeIntervalSince1970: stamp))
    }
}

extension FeedService {
    func stocks(_ configuration: FeedConfiguration) async throws -> FeedBatch {
        let symbols = try StockSymbols.normalize(configuration.stockSymbols)
        var quotes: [RadioItem] = []
        var warnings: [String] = []
        var successfulQuotes = 0
        // Keep requests bounded, and preserve the watchlist order across completions.
        for start in stride(from: 0, to: symbols.count, by: 3) {
            try Task.checkCancellation()
            let group = Array(symbols[start..<min(start + 3, symbols.count)])
            let results = await withTaskGroup(of: (Int, StockQuote).self) { tasks in
                for (index, symbol) in group.enumerated() {
                    tasks.addTask {
                        do { return (index, try StockQuote.parse(await download(StockQuote.endpoint(symbol)), symbol: symbol)) }
                        catch { return (index, .unavailable(symbol)) }
                    }
                }
                var values: [(Int, StockQuote)] = []
                for await value in tasks { values.append(value) }
                return values.sorted { $0.0 < $1.0 }.map(\.1)
            }
            try Task.checkCancellation()
            for quote in results {
                quotes.append(quote.item)
                if quote.price != nil { successfulQuotes += 1 }
                else { warnings.append("Quote unavailable: " + quote.symbol) }
            }
        }
        var headlines: [RadioItem] = []
        var newsSucceeded = false
        do {
            let batch = try await news(channel: .stocks, configuration: configuration)
            headlines = batch.items; newsSucceeded = true
            if let warning = batch.warning { warnings.append(warning) }
        } catch {
            try Task.checkCancellation()
            warnings.append(error.localizedDescription)
        }
        guard newsSucceeded || successfulQuotes > 0 else {
            throw FeedError.message(warnings.joined(separator: " · "))
        }
        return FeedBatch(items: quotes + headlines, fetchedAt: Date(),
                         warning: warnings.isEmpty ? nil : warnings.joined(separator: " · "))
    }
}
