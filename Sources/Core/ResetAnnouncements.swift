import Foundation

enum ResetAnnouncements {
    static let endpoint = URL(string: "https://codex-resets.com/api/v1/resets")!
    static let attribution = URL(string: "https://codex-resets.com")!

    static func parse(_ data: Data, now: Date = Date()) throws -> FeedBatch {
        // Decode rows independently so a malformed entry cannot hide all valid announcements.
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = object["data"] as? [[String: Any]] else {
            throw FeedError.message("The reset tracker returned unreadable data.")
        }
        var items: [RadioItem] = []
        var seen = Set<String>()
        var invalid = 0
        var candidates = 0
        for row in rows {
            // The API also publishes community-observed events. They are outside this
            // station's X-announcement scope, rather than a source failure.
            if (row["source"] as? [String: Any])?["type"] as? String == "observed" { continue }
            candidates += 1
            guard let id = row["id"] as? String, id.range(of: "^[0-9]{1,30}$", options: .regularExpression) != nil,
                  let kind = row["reset_type"] as? String, ["regular", "banked"].contains(kind),
                  let text = row["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let rawDate = row["announced_at"] as? String, let date = FeedParser.date(rawDate),
                  date <= now, date.timeIntervalSince1970 > 0,
                  let source = row["source"] as? [String: Any],
                  source["type"] as? String == "x_post",
                  (source["author"] as? String)?.lowercased() == "thsottiaux",
                  let rawURL = source["url"] as? String, let url = URL(string: rawURL),
                  url.scheme == "https", ["x.com", "twitter.com"].contains(url.host?.lowercased() ?? ""),
                  url.user == nil, url.password == nil, url.port == nil, url.query == nil, url.fragment == nil,
                  url.path.lowercased() == "/thsottiaux/status/" + id else { invalid += 1; continue }
            guard seen.insert(id).inserted else { continue }
            items.append(RadioItem(id: "reset:" + id, title: kind == "banked" ? "Banked reset announced" : "Codex reset announced",
                                   excerpt: String(FeedParser.clean(text).prefix(340)),
                                   source: "Tibo (@thsottiaux) · Codex Resets", url: url, publishedAt: date,
                                   metric: kind == "banked" ? "BANKED RESET" : "RESET ANNOUNCEMENT"))
        }
        guard candidates == 0 || !items.isEmpty else { throw FeedError.message("No valid reset announcements were received.") }
        return FeedBatch(items: Array(items.sorted { $0.publishedAt! > $1.publishedAt! }.prefix(200)), fetchedAt: now,
                         warning: invalid > 0 ? "Some reset announcements could not be verified." : nil)
    }
}

/// Persistent deduplication with a quiet first successful nonempty snapshot.
struct ResetAlertLedger: Codable {
    private(set) var highWaterDate: Date?
    private(set) var seenIDs: [String] = []
    mutating func consume(_ items: [RadioItem], now: Date = Date()) -> [RadioItem] {
        let valid = items.filter { item in
            guard item.id.hasPrefix("reset:"), let date = item.publishedAt else { return false }
            return date <= now && date.timeIntervalSince1970 > 0
        }.sorted { $0.publishedAt! > $1.publishedAt! }
        guard let latest = valid.first?.publishedAt else { return [] }
        let seen = Set(seenIDs)
        let result = highWaterDate.map { high in
            valid.filter { !seen.contains($0.id) && $0.publishedAt! > high && now.timeIntervalSince($0.publishedAt!) <= 86400 }
        } ?? []
        highWaterDate = max(highWaterDate ?? latest, latest)
        var unique = Set<String>()
        seenIDs = Array((valid.map(\.id) + seenIDs).filter { unique.insert($0).inserted }.prefix(256))
        return result
    }
}
