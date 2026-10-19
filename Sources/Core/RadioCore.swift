import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import CryptoKit

struct RadioChannel: RawRepresentable, Hashable, Codable, CaseIterable {
 let rawValue: String
 init?(rawValue: String) { guard Self.names[rawValue] != nil || (rawValue.hasPrefix("custom:") && rawValue.dropFirst(7).range(of: "^[A-Za-z0-9][A-Za-z0-9-]{0,127}$", options: .regularExpression) != nil) else { return nil }; self.rawValue = rawValue }
 static let codex = Self(rawValue: "codex")!
 static let ai = Self(rawValue: "ai")!, github = Self(rawValue: "github")!, research = Self(rawValue: "research")!, custom = Self(rawValue: "custom")!, games = Self(rawValue: "games")!, nba = Self(rawValue: "nba")!, education = Self(rawValue: "education")!, psychology = Self(rawValue: "psychology")!, philosophy = Self(rawValue: "philosophy")!, science = Self(rawValue: "science")!, technology = Self(rawValue: "technology")!
 private static let names = ["codex":"Codex", "ai":"AI News", "github":"GitHub", "research":"Research", "custom":"Your Feed", "games":"Games", "nba":"NBA", "education":"Education", "psychology":"Psychology", "philosophy":"Philosophy", "science":"Science", "technology":"Technology"]
 static var allCases: [Self] { [.ai,.github,.research,.games,.nba,.education,.psychology,.philosophy,.science,.technology,.codex,.custom] }
 static func station(_ id: String) -> Self { Self(rawValue: "custom:" + id) ?? .custom }
 var title: String { Self.names[rawValue] ?? "Your Station" }
 var subtitle: String { self == .codex ? "Recorded token activity on this Mac" : self == .github ? "Recently trending open source" : self == .research ? "Fresh preprints from arXiv" : self == .nba ? "Scores and tomorrow’s matchups" : "Fresh perspectives on " + title.lowercased() }
 init(from decoder: Decoder) throws { let box = try decoder.singleValueContainer(); let raw = try box.decode(String.self); guard let value = Self(rawValue: raw) else { throw DecodingError.dataCorruptedError(in: box, debugDescription: "Invalid station") }; self = value }
 func encode(to encoder: Encoder) throws { var box = encoder.singleValueContainer(); try box.encode(rawValue) }
}
enum GitHubPeriod: String, Codable, CaseIterable { case daily, weekly, monthly; var title: String { switch self { case .daily: return "Today"; case .weekly: return "This week"; case .monthly: return "This month" } } }
struct CustomStation: Identifiable, Codable, Equatable {
 var id: String; var title: String; var feedURLs: [String]; var webpageURLs: [String]; var keywords: String; var enabled: Bool
 init(id: String = UUID().uuidString, title: String, feedURLs: [String], webpageURLs: [String] = [], keywords: String = "", enabled: Bool = true) { self.id=id; self.title=title; self.feedURLs=feedURLs; self.webpageURLs=webpageURLs; self.keywords=keywords; self.enabled=enabled }
 enum CodingKeys: String, CodingKey { case id, title, feedURLs, webpageURLs, keywords, enabled }
 init(from decoder: Decoder) throws {
 let c = try decoder.container(keyedBy: CodingKeys.self)
 id = try c.decode(String.self, forKey: .id); title = try c.decode(String.self, forKey: .title)
 feedURLs = try c.decodeIfPresent([String].self, forKey: .feedURLs) ?? []
 webpageURLs = try c.decodeIfPresent([String].self, forKey: .webpageURLs) ?? []
 keywords = try c.decodeIfPresent(String.self, forKey: .keywords) ?? ""
 enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
 }
}
struct RadioItem: Identifiable, Codable, Equatable {
 let id: String; let title: String; let excerpt: String; let source: String; let url: URL; let publishedAt: Date?; let metric: String?
}
struct FeedConfiguration: Codable, Equatable {
 var githubQuery: String; var customFeedURL: String
 var githubPeriod: GitHubPeriod = .daily
 var aiSourceIDs = ["openai","anthropic","deepmind","huggingface","mit-ai","bair"]
 var researchTopics = ["cs.AI","physics"]
 var enabledChannels = ["ai","github","research"]
 var customStations: [CustomStation] = []
 init(githubQuery: String = "stars:>10000", customFeedURL: String = "") { self.githubQuery=githubQuery; self.customFeedURL=customFeedURL }
 enum CodingKeys: String, CodingKey { case githubQuery,customFeedURL,githubPeriod,aiSourceIDs,researchTopics,enabledChannels,customStations }
 init(from decoder: Decoder) throws { self.init(); let c = try decoder.container(keyedBy: CodingKeys.self)
 githubQuery = try c.decodeIfPresent(String.self, forKey: .githubQuery) ?? githubQuery
 customFeedURL = try c.decodeIfPresent(String.self, forKey: .customFeedURL) ?? customFeedURL
 githubPeriod = try c.decodeIfPresent(GitHubPeriod.self, forKey: .githubPeriod) ?? githubPeriod
 aiSourceIDs = try c.decodeIfPresent([String].self, forKey: .aiSourceIDs) ?? aiSourceIDs
 researchTopics = try c.decodeIfPresent([String].self, forKey: .researchTopics) ?? researchTopics
 enabledChannels = try c.decodeIfPresent([String].self, forKey: .enabledChannels) ?? enabledChannels
 customStations = try c.decodeIfPresent([CustomStation].self, forKey: .customStations) ?? customStations }
}
struct FeedBatch: Codable { let items: [RadioItem]; let fetchedAt: Date; let warning: String? }
struct RadioCache {
 let directory: URL
 init(directory: URL) { self.directory = directory }
 private func file(channel: RadioChannel, configuration: FeedConfiguration) -> URL {
 var scope = "v2:" + channel.rawValue
 switch channel { case .github: scope += configuration.githubPeriod.rawValue
 case .ai: scope += configuration.aiSourceIDs.sorted().joined(separator: ",")
 case .research: scope += configuration.researchTopics.sorted().joined(separator: ",")
 case .custom: scope += configuration.customFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
 default: if let station = configuration.customStations.first(where: { "custom:" + $0.id == channel.rawValue }) { scope += station.feedURLs.sorted().joined(separator: "|") + ":" + station.keywords.lowercased(); if !station.webpageURLs.isEmpty { scope += ":webpages:" + station.webpageURLs.sorted().joined(separator: "|") } } }
 let hash = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
 return directory.appendingPathComponent("v2-\(hash).json")
 }
 func load(channel: RadioChannel, configuration: FeedConfiguration) -> FeedBatch? {
 guard let data = try? Data(contentsOf: file(channel: channel, configuration: configuration)) else { return nil }
 return try? JSONDecoder().decode(FeedBatch.self, from: data)
 }
 func save(_ batch: FeedBatch, channel: RadioChannel, configuration: FeedConfiguration) throws {
 try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
 try JSONEncoder().encode(batch).write(to: file(channel: channel, configuration: configuration), options: .atomic)
 }
}
enum FeedError: LocalizedError {
 case message(String)
 var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
enum FeedParser {
 static func parse(_ data: Data, source: String) throws -> [RadioItem] {
 let delegate = XMLFeedDelegate(source: source)
 let parser = XMLParser(data: data)
 parser.shouldResolveExternalEntities = false
 parser.delegate = delegate
 guard parser.parse() else { throw FeedError.message("\(source) returned an unreadable RSS or Atom feed.") }
 return delegate.items
 }
 static func clean(_ text: String) -> String {
 var value = text.replacingOccurrences(of: "(?is)<(script|style)\\b[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
 value = value.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
 let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&nbsp;": " "]
 for (key, replacement) in entities { value = value.replacingOccurrences(of: key, with: replacement) }
 if let regex = try? NSRegularExpression(pattern: "&#(x[0-9a-fA-F]+|[0-9]+);") {
 for match in regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
 guard let range = Range(match.range, in: value), let digits = Range(match.range(at: 1), in: value) else { continue }
 let raw = String(value[digits]); let number = raw.hasPrefix("x") ? UInt32(raw.dropFirst(), radix: 16) : UInt32(raw)
 if let number, let scalar = UnicodeScalar(number) { value.replaceSubrange(range, with: String(scalar)) }
 }
 }
 value = value.replacingOccurrences(of: "(?is)^arXiv:.*?Abstract:\\s*", with: "", options: .regularExpression)
 return value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
 }
 static func date(_ text: String) -> Date? {
 let iso = ISO8601DateFormatter()
 if let date = iso.date(from: text) { return date }
 iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
 if let date = iso.date(from: text) { return date }
 // ESPN scoreboards omit seconds. Normalize only complete ISO minute timestamps,
 // retaining their explicit UTC/offset zone before using the strict ISO parser.
 if text.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:?[0-9]{2})$", options: .regularExpression) != nil {
 let withSeconds = text.replacingOccurrences(of: "(T[0-9]{2}:[0-9]{2})(Z|[+-][0-9]{2}:?[0-9]{2})$", with: "$1:00$2", options: .regularExpression)
 iso.formatOptions = [.withInternetDateTime]
 if let date = iso.date(from: withSeconds) { return date }
 }
 let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
 for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"] {
 formatter.dateFormat = format
 if let date = formatter.date(from: text) { return date }
 }
 return nil
 }
}
private final class XMLFeedDelegate: NSObject, XMLParserDelegate {
 let source: String
 var items: [RadioItem] = []
 var active = false; var depth = 0; var fieldDepth = 0; var field: String?; var fields: [String: String] = [:]; var href: String?; var categories: [String] = []
 init(source: String) { self.source = source }
 func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
 let name = elementName.lowercased(); depth += 1
 if name == "item" || name == "entry" { active = true; fields = [:]; href = nil; field = nil; categories = []; return }
 guard active else { return }
 if name == "category", let term = attributes["term"] { categories.append(term) }
 if name == "link", let link = attributes["href"], attributes["rel"] == nil || attributes["rel"] == "alternate" { href = link }
 if field == nil, ["title", "link", "description", "summary", "content", "content:encoded", "pubdate", "published", "updated", "dc:date", "category"].contains(name) { field = name; fieldDepth = depth; fields[name] = "" }
 }
 func parser(_ parser: XMLParser, foundCharacters string: String) { if let field { fields[field, default: ""] += string } }
 func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { if let string = String(data: CDATABlock, encoding: .utf8) { self.parser(parser, foundCharacters: string) } }
 func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
 let name = elementName.lowercased()
 if active && name == "category", let value = fields["category"], !value.isEmpty { categories.append(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
 if let field, ["p", "div", "br", "li"].contains(name), depth > fieldDepth { fields[field, default: ""] += " " }
 if active && (name == "item" || name == "entry") {
 let link = (href ?? fields["link"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
 if let url = URL(string: link), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil, url.user == nil, url.password == nil {
 let title = FeedParser.clean(fields["title"] ?? "Untitled")
 let content = ["description", "summary", "content:encoded", "content"].compactMap { fields[$0] }.map(FeedParser.clean).first { !$0.isEmpty } ?? ""
 let excerpt = String(content.prefix(340))
 let published = ["pubdate", "published", "updated", "dc:date"].compactMap { fields[$0] }.compactMap { FeedParser.date($0.trimmingCharacters(in: .whitespacesAndNewlines)) }.first
 items.append(RadioItem(id: url.absoluteString, title: title, excerpt: excerpt, source: source.hasPrefix("arXiv") && !categories.isEmpty ? "arXiv · " + categories.joined(separator: ", ") + " · Preprint" : source, url: url, publishedAt: published, metric: nil))
 }
 active = false; field = nil
 }
 if depth == fieldDepth { field = nil }
 depth -= 1
 }
}
struct FeedService {
 private let downloader: ((URL) async throws -> Data)?
 init(downloader: ((URL) async throws -> Data)? = nil) { self.downloader = downloader }
 func fetch(channel: RadioChannel, configuration: FeedConfiguration) async throws -> FeedBatch {
 try Task.checkCancellation()
 if channel == .github { return try await github(configuration.githubPeriod) }
 if channel == .nba { return try await nba() }
 var sources: [StationSource] = []; var keywords: [String] = []
 if channel == .ai {
 guard configuration.aiSourceIDs.allSatisfy({ id in StationCatalog.aiSources.contains { $0.id == id } }) else { throw FeedError.message("Choose valid AI sources.") }
 sources = StationCatalog.aiSources.filter { configuration.aiSourceIDs.contains($0.id) }
 } else if channel == .research {
 guard !configuration.researchTopics.isEmpty, configuration.researchTopics.allSatisfy({ id in StationCatalog.researchTopics.contains { $0.id == id } }) else { throw FeedError.message("Choose valid research topics.") }
 sources = [StationSource(id: "arxiv", title: "arXiv", url: "https://rss.arxiv.org/rss/" + configuration.researchTopics.joined(separator: "+"), perspective: "Preprint")]
 } else if channel == .custom || channel.rawValue.hasPrefix("custom:") {
 let addresses: [String]; let title: String; var pages: [String] = []
 if channel == .custom { addresses = [configuration.customFeedURL]; title = "Your feed" }
 else { guard let station = configuration.customStations.first(where: { "custom:" + $0.id == channel.rawValue }), station.enabled else { throw FeedError.message("This station is unavailable.") }; addresses = station.feedURLs; pages = station.webpageURLs; title = station.title; keywords = station.keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty } }
 guard !addresses.isEmpty || !pages.isEmpty else { throw FeedError.message("Add an HTTPS feed URL.") }
 for address in addresses + pages { let text = address.trimmingCharacters(in: .whitespacesAndNewlines); guard let url = URL(string: text), url.scheme?.lowercased() == "https", url.host != nil, url.user == nil, url.password == nil else { throw FeedError.message("Enter a valid HTTPS feed URL.") }; sources.append(StationSource(id: text, title: title, url: text, perspective: "", kind: pages.contains(address) ? .webpage : .feed)) }
 } else { sources = StationCatalog.sources(for: channel) }
 guard !sources.isEmpty else { throw FeedError.message("Choose at least one source.") }
 var groups: [[RadioItem]] = []; var failures: [String] = []; var successes = 0
 for source in sources {
 do { try Task.checkCancellation()
 let label = source.title + (source.perspective.isEmpty ? "" : " · " + source.perspective)
 var parsed: [RadioItem]
 if source.kind == .webpage {
 let url = URL(string: source.url)!
 let page: DiscoveryPage
 if let downloader { page = DiscoveryPage(data: try await downloader(url), url: url) }
 else { page = try await FeedDiscovery.download(url) }
 try Task.checkCancellation()
 parsed = try WebpageReader.parse(page.data, pageURL: page.url, source: label).items
 } else {
 let data = try await download(URL(string: source.url)!)
 parsed = try source.id == "anthropic" ? AnthropicNews.parse(data, source: label) : FeedParser.parse(data, source: label)
 }
 successes += 1
 if channel == .ai && ["microsoft","nvidia","ars"].contains(source.id) { parsed = parsed.filter { ($0.title + " " + $0.excerpt).range(of: "(?i)artificial intelligence|\\bAI\\b|machine learning|neural|LLM|language model", options: .regularExpression) != nil } }
 if !keywords.isEmpty { parsed = parsed.filter { item in keywords.contains { (item.title + " " + item.excerpt).lowercased().contains($0) } } }
 let sorted = source.kind == .webpage ? parsed : parsed.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
 if channel == .research {
 var assigned = Set<String>()
 for topic in configuration.researchTopics {
 let matching = sorted.filter { item in
 let labels = item.source.components(separatedBy: " · ").dropFirst().first?.components(separatedBy: ", ") ?? []
 return labels.contains { $0 == topic || $0.hasPrefix(topic + ".") } && assigned.insert(item.id).inserted
 }
 groups.append(matching)
 }
 groups.append(sorted.filter { !assigned.contains($0.id) })
 } else { groups.append(sorted) }
 } catch is CancellationError { throw CancellationError() } catch { try Task.checkCancellation(); failures.append(source.title + ": " + error.localizedDescription) }
 }
 guard successes > 0 else { throw FeedError.message(failures.joined(separator: "\n")) }
 var items: [RadioItem] = []; var seen = Set<String>(); var index = 0
 while groups.contains(where: { $0.count > index }) && items.count < 30 { for group in groups where group.count > index { let item = group[index]; if seen.insert(item.url.absoluteString).inserted { items.append(item) }; if items.count == 30 { break } }; index += 1 }
 try Task.checkCancellation()
 return FeedBatch(items: items, fetchedAt: Date(), warning: failures.isEmpty ? nil : failures.joined(separator: "\n"))
 }
 private func download(_ url: URL) async throws -> Data {
 try Task.checkCancellation()
 if let downloader {
 let data = try await downloader(url)
 guard !data.isEmpty, data.count <= 12_000_000 else { throw FeedError.message("The source returned an empty or unusually large feed.") }
 try Task.checkCancellation()
 return data
 }
 let config = URLSessionConfiguration.ephemeral
 config.timeoutIntervalForRequest = 18; config.timeoutIntervalForResource = 25
 let session = URLSession(configuration: config)
 defer { session.invalidateAndCancel() }
 var request = URLRequest(url: url); request.setValue("Catecho/1.0 (macOS; public feed reader)", forHTTPHeaderField: "User-Agent")
 request.setValue("application/rss+xml, application/atom+xml, application/xml, application/json, text/xml;q=0.9, */*;q=0.5", forHTTPHeaderField: "Accept")
 do {
 let (data, response) = try await session.data(for: request)
 try Task.checkCancellation()
 guard let http = response as? HTTPURLResponse else { throw FeedError.message("The server returned an invalid response.") }
 guard http.url?.scheme?.lowercased() == "https" || (url.scheme == "http" && http.url?.scheme == "http") else { throw FeedError.message("The feed redirected to an insecure address.") }
 if http.statusCode == 403 || http.statusCode == 429 { throw FeedError.message("The source is limiting requests. Wait a few minutes and try again.") }
 guard (200...299).contains(http.statusCode) else { throw FeedError.message("The source returned HTTP \(http.statusCode). Try again later.") }
 guard !data.isEmpty, data.count <= 12_000_000 else { throw FeedError.message("The source returned an empty or unusually large feed.") }
 return data
 } catch let error as URLError {
 try Task.checkCancellation()
 if error.code == .cancelled { throw CancellationError() }
 if error.code == .notConnectedToInternet || error.code == .networkConnectionLost { throw FeedError.message("You appear to be offline. Check your connection and try again.") }
 if error.code == .timedOut { throw FeedError.message("The source took too long to respond. Try again shortly.") }
 throw FeedError.message("Could not reach the source: \(error.localizedDescription)")
 }
 }
 private func github(_ period: GitHubPeriod) async throws -> FeedBatch {
 let data = try await download(URL(string: "https://github.com/trending?since=" + period.rawValue)!)
 guard let html = String(data: data, encoding: .utf8) else { throw FeedError.message("GitHub Trending returned unreadable HTML.") }
 func captures(_ pattern: String, _ text: String) -> [String] { guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }; return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } } }
 let rows = captures("<article[^>]*class=[\"'][^\"']*Box-row[^\"']*[\"'][^>]*>(.*?)</article>", html)
 guard !rows.isEmpty else { throw FeedError.message("GitHub Trending's page layout changed. Try again later.") }
 var items: [RadioItem] = []; var seen = Set<String>()
 for row in rows {
 guard let heading = captures("<h2\\b[^>]*>(.*?)</h2>", row).first, let path = captures("href=[\"']([^\"']+)[\"']", heading).first,
 path.range(of: "^/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", options: .regularExpression) != nil, !path.hasPrefix("/sponsors/"), seen.insert(path).inserted else { continue }
 let gainSpans = captures("<span\\b[^>]*class=[\"'][^\"']*\\bfloat-sm-right\\b[^\"']*[\"'][^>]*>(.*?)</span>", row).map(FeedParser.clean)
 let suffix = period == .daily ? "today" : period == .weekly ? "this week" : "this month"
 let gain = gainSpans.compactMap { captures("([0-9][0-9,]*) stars " + suffix, $0).first }.first
 let metric = gain.map { "+" + $0 + " stars " + suffix }
 let description = captures("<p\\b[^>]*>(.*?)</p>", row).first.map(FeedParser.clean) ?? ""
 let url = URL(string: "https://github.com" + path)!
 items.append(RadioItem(id: url.absoluteString, title: String(path.dropFirst()), excerpt: String(description.prefix(340)), source: "GitHub Trending", url: url, publishedAt: nil, metric: metric))
 }
 guard !items.isEmpty else { throw FeedError.message("GitHub Trending returned no readable repositories; its page layout may have changed.") }
 return FeedBatch(items: Array(items.prefix(30)), fetchedAt: Date(), warning: items.contains { $0.metric == nil } ? "Some repositories have no recent star gain reported by GitHub." : nil)
 }
 private func nba() async throws -> FeedBatch {
 var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
 let now = Date(); let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyyMMdd"
 let start = formatter.string(from: calendar.date(byAdding: .day, value: -1, to: now)!); let end = formatter.string(from: calendar.date(byAdding: .day, value: 1, to: now)!)
 let base = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates="
 var events: [[String: Any]] = []; var coverageWarnings: [String] = []
 func decodeEvents(_ data: Data) throws -> [[String: Any]] {
 guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let result = root["events"] as? [[String: Any]] else { throw FeedError.message("ESPN returned an unreadable scoreboard.") }; return result
 }
 func readable(_ event: [String: Any]) -> Bool {
 guard let id = event["id"] as? String, !id.isEmpty, let competition = (event["competitions"] as? [[String: Any]])?.first, let teams = competition["competitors"] as? [[String: Any]], teams.count == 2 else { return false }
 let status = (event["status"] as? [String: Any]) ?? (competition["status"] as? [String: Any]) ?? [:]
 let type = status["type"] as? [String: Any] ?? [:]
 return ["pre", "in", "post"].contains(type["state"] as? String ?? "")
 }
 var successes = 0; var ids = Set<String>(); var malformedEvents = 0
 for offset in -1...1 {
 try Task.checkCancellation()
 let date = formatter.string(from: calendar.date(byAdding: .day, value: offset, to: now)!)
 do { let day = try decodeEvents(await download(URL(string: base + date + "&limit=100")!)); successes += 1
 let readableDay = day.filter(readable)
 let skipped = day.count - readableDay.count; malformedEvents += skipped
 if skipped > 0 { coverageWarnings.append(date + ": " + String(skipped) + " malformed game(s) omitted (missing teams, id, or recognized status).") }
 events += readableDay.filter { ids.insert($0["id"] as! String).inserted }
 } catch is CancellationError { throw CancellationError() } catch { coverageWarnings.append(date + ": " + error.localizedDescription) }
 }
 guard successes > 0 else { throw FeedError.message(coverageWarnings.joined(separator: "\n")) }
 guard !events.isEmpty || malformedEvents == 0 else { throw FeedError.message(coverageWarnings.joined(separator: "\n")) }
 var ranked: [(Int, RadioItem)] = []
 for event in events {
 guard let id = event["id"] as? String, let competition = (event["competitions"] as? [[String: Any]])?.first, let teams = competition["competitors"] as? [[String: Any]], teams.count == 2 else { continue }
 let status = (event["status"] as? [String: Any]) ?? (competition["status"] as? [String: Any]) ?? [:]; let type = status["type"] as? [String: Any] ?? [:]; let state = type["state"] as? String ?? "unknown"; let completed = type["completed"] as? Bool ?? false
 let date = (event["date"] as? String).flatMap(FeedParser.date)
 let ordered = teams.sorted { ($0["homeAway"] as? String == "away" ? 0 : 1) < ($1["homeAway"] as? String == "away" ? 0 : 1) }
 func name(_ team: [String: Any]) -> String { let t = team["team"] as? [String: Any] ?? [:]; return t["abbreviation"] as? String ?? t["displayName"] as? String ?? "Team" }
 let scored = state == "in" || completed || state == "post"
 let title = scored ? ordered.map { name($0) + " " + (($0["score"] as? String) ?? "–") }.joined(separator: " · ") : ordered.map(name).joined(separator: " at ")
 let detail = type["detail"] as? String ?? type["description"] as? String ?? "Scheduled"
 var parts = [detail]
 if state == "in", let clock = status["displayClock"] as? String { parts.append("Period \(status["period"] as? Int ?? 0) · " + clock) }
 if !scored, let date { parts.append(date.formatted(.iso8601)) }
 for team in ordered {
 let stats = (team["statistics"] as? [[String: Any]] ?? []).filter { ["rebounds","assists","fieldGoalPct","threePointPct","freeThrowPct"].contains($0["name"] as? String ?? "") }.compactMap { stat -> String? in guard let value = stat["displayValue"] as? String else { return nil }; return (stat["abbreviation"] as? String ?? stat["name"] as? String ?? "") + " " + value }
 if !stats.isEmpty { parts.append(name(team) + ": " + stats.joined(separator: ", ")) }
 for group in team["leaders"] as? [[String: Any]] ?? [] where group["name"] as? String == "points" { if let leader = (group["leaders"] as? [[String: Any]])?.first, let athlete = leader["athlete"] as? [String: Any], let player = athlete["displayName"] as? String, let value = leader["displayValue"] as? String { parts.append(player + " " + value + " points") } }
 }
 let exceptional = (type["name"] as? String ?? "").replacingOccurrences(of: "STATUS_", with: "")
 let metric = ["POSTPONED","CANCELED","CANCELLED","DELAYED","SUSPENDED"].contains(exceptional) ? exceptional : state == "in" ? "LIVE" : completed || state == "post" ? "FINAL" : "SCHEDULED"
 let item = RadioItem(id: "nba:" + id, title: title, excerpt: parts.joined(separator: " · "), source: "ESPN · Public scoreboard", url: URL(string: "https://www.espn.com/nba/game/_/gameId/" + id.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)!, publishedAt: date, metric: metric)
 let rank = state == "in" ? 0 : date.map { calendar.isDate($0, inSameDayAs: now) ? 1 : $0 > now ? 2 : 3 } ?? 4
 ranked.append((rank,item))
 }
 if !events.isEmpty && ranked.isEmpty { throw FeedError.message("ESPN returned games without readable teams.") }
 let items = ranked.sorted { $0.0 == $1.0 ? ($0.1.publishedAt ?? .distantPast) < ($1.1.publishedAt ?? .distantPast) : $0.0 < $1.0 }.map { $0.1 }
 if items.isEmpty { return FeedBatch(items: [RadioItem(id: "nba:empty:" + start, title: "No NBA games scheduled", excerpt: "ESPN lists no games in successfully checked dates within \(start)–\(end) (US Eastern).", source: "ESPN · Public scoreboard", url: URL(string: "https://www.espn.com/nba/scoreboard")!, publishedAt: nil, metric: nil)], fetchedAt: now, warning: coverageWarnings.isEmpty ? nil : coverageWarnings.joined(separator: "\n")) }
 try Task.checkCancellation()
 return FeedBatch(items: Array(items.prefix(30)), fetchedAt: now, warning: coverageWarnings.isEmpty ? nil : coverageWarnings.joined(separator: "\n"))
 }
}
