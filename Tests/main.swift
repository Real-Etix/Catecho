import Foundation
@main struct CoreTests {
 static func check(_ value: @autoclosure () -> Bool, _ name: String) { if !value() { fatalError("FAIL: \(name)") }; print("PASS: \(name)") }
 static func main() async throws {
 let old = try JSONDecoder().decode(FeedConfiguration.self, from: Data("{\"githubQuery\":\"old\",\"customFeedURL\":\"\"}".utf8))
 check(old.githubPeriod == .daily && old.aiSourceIDs.contains("anthropic"), "backward configuration defaults include Anthropic")
 let savedAI = try JSONDecoder().decode(FeedConfiguration.self, from: Data(#"{"aiSourceIDs":["bair"]}"#.utf8))
 check(savedAI.aiSourceIDs == ["bair"], "existing source choices are preserved")
 var claudeConfig = FeedConfiguration(); claudeConfig.aiSourceIDs = ["anthropic"]
 let newsroom = """
 <a href="/news/example-release"><h2>Claude &amp; research</h2><time>Oct 6, 2026</time><p>A publisher-written excerpt.</p></a>
 <a class="row" href='/news/newer-update'><time datetime="2026-10-15">Oct 15, 2026</time><span class="PublicationList__title body-3">Newer update</span></a>
 <a href="/news/example-release"><time>Oct 6, 2026</time><span class="PublicationList__title">Claude &amp; research</span></a>
 <a href="https://evil.test/news/injected"><h2>Unsafe</h2><time>Oct 16, 2026</time></a>
 <a href="/news/navigation">News navigation</a>
 """
 let claude = try await FeedService(downloader: { url in
 check(url.absoluteString == "https://www.anthropic.com/news", "Anthropic uses official newsroom")
 return Data(newsroom.utf8)
 }).fetch(channel: .ai, configuration: claudeConfig)
 check(claude.items.count == 2 && claude.items[0].title == "Newer update", "newsroom dated stories sorted, deduplicated and restricted to official links")
 check(claude.items[0].excerpt.isEmpty && claude.items[1].excerpt == "A publisher-written excerpt." && claude.items[1].title == "Claude & research", "newsroom preserves real excerpts without fabricating summaries")
 for html in ["<html>Unavailable</html>", "<a href='/news/no-date'><h2>Missing date</h2></a>"] {
 do { _ = try await FeedService(downloader: { _ in Data(html.utf8) }).fetch(channel: .ai, configuration: claudeConfig); fatalError("accepted unreadable newsroom") } catch { print("PASS: newsroom layout failure throws for cache preservation") }
 }
 if let index = CommandLine.arguments.firstIndex(of: "--anthropic-fixture"), CommandLine.arguments.count > index + 1 {
 let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
 let actual = try await FeedService(downloader: { _ in data }).fetch(channel: .ai, configuration: claudeConfig)
 check(actual.items.count >= 5 && actual.items.allSatisfy { $0.publishedAt != nil && $0.url.host == "www.anthropic.com" }, "downloaded official newsroom parses dated stories")
 print("NEWSROOM: \(actual.items.count) stories; latest: \(actual.items.first!.title)")
 }
 check(RadioChannel(rawValue: "custom:../../bad") == nil, "unsafe station ID rejected")
 check(RadioChannel.station("demo").rawValue == "custom:demo", "dynamic channel")
 let trend = "<article class=\"Box-row\"><h2><a href=\"/swiftlang/swift\">swiftlang / swift</a></h2><p>Swift language: 100 stars today</p><span class=\"float-sm-right f6\">1,234 stars today</span></article>"
 let trendBatch = try await FeedService(downloader: { url in
 check(url.absoluteString == "https://github.com/trending?since=daily", "GitHub period URL")
 return Data(trend.utf8)
 }).fetch(channel: .github, configuration: FeedConfiguration())
 check(trendBatch.items.first?.metric == "+1,234 stars today", "GitHub recent gain")
 for (html, label) in [("<html>changed</html>", "changed layout"), ("<article class=\"Box-row\"><h2><a href=\"https://evil.test/a/b\">Bad</a></h2></article>", "unsafe repository")] {
 do { _ = try await FeedService(downloader: { _ in Data(html.utf8) }).fetch(channel: .github, configuration: FeedConfiguration()); fatalError("accepted " + label) } catch { print("PASS: Trending rejects " + label) }
 }
 let noMetric = trend.replacingOccurrences(of: "1,234 stars today", with: "123,456")
 let noMetricBatch = try await FeedService(downloader: { _ in Data(noMetric.utf8) }).fetch(channel: .github, configuration: FeedConfiguration())
 check(noMetricBatch.items.first?.metric == nil && noMetricBatch.warning != nil, "no accumulated star fallback")
 let descriptionOnly = trend.replacingOccurrences(of: "1,234 stars today", with: "123,456")
 let descriptionBatch = try await FeedService(downloader: { _ in Data(descriptionOnly.utf8) }).fetch(channel: .github, configuration: FeedConfiguration())
 check(descriptionBatch.items.first?.metric == nil && descriptionBatch.warning != nil, "description cannot supply Trending gain")
 let nbaJSON = """
 {"events":[{"id":"123","date":"2026-10-16T23:00:00Z","status":{"type":{"state":"in","detail":"3rd Quarter","completed":false},"period":3,"displayClock":"4:12"},"competitions":[{"competitors":[{"homeAway":"home","score":"108","team":{"abbreviation":"BOS"}},{"homeAway":"away","score":"112","team":{"abbreviation":"LAL"},"statistics":[{"name":"rebounds","abbreviation":"REB","displayValue":"35"}]}]}]}]}
 """
 check(FeedParser.date("2026-10-15T23:30Z") == FeedParser.date("2026-10-15T23:30:00Z"), "ESPN minute precision timestamp parses")
 check(FeedParser.date("2026-10-15T19:30-04:00") == FeedParser.date("2026-10-15T23:30:00Z"), "minute precision preserves timezone offset")
 let root = try JSONSerialization.jsonObject(with: Data(nbaJSON.utf8)) as! [String: Any]
 let validEvent = (root["events"] as! [[String: Any]])[0]
 var minuteEvent = validEvent; minuteEvent["date"] = "2026-10-15T23:30Z"
 let minuteData = try JSONSerialization.data(withJSONObject: ["events": [minuteEvent]])
 let minuteBatch = try await FeedService(downloader: { _ in minuteData }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(minuteBatch.items.first?.publishedAt == FeedParser.date("2026-10-15T23:30:00Z"), "NBA actual ESPN minute timestamp retains published date")
 var orderCalendar = Calendar(identifier: .gregorian); orderCalendar.timeZone = TimeZone(identifier: "America/New_York")!
 let minuteFormatter = DateFormatter(); minuteFormatter.locale = Locale(identifier: "en_US_POSIX"); minuteFormatter.timeZone = TimeZone(secondsFromGMT: 0); minuteFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
 let todayNoon = orderCalendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
 let orderingEvents: [[String: Any]] = [("recent", -1, "post"), ("upcoming", 1, "pre"), ("today", 0, "pre"), ("live", -1, "in")].map { id, offset, state in
 var event = validEvent; event["id"] = id; event["date"] = minuteFormatter.string(from: orderCalendar.date(byAdding: .day, value: offset, to: todayNoon)!)
 event["status"] = ["type": ["state": state]]
 return event
 }
 let orderingData = try JSONSerialization.data(withJSONObject: ["events": orderingEvents])
 let orderingBatch = try await FeedService(downloader: { _ in orderingData }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(orderingBatch.items.map(\.id) == ["nba:live", "nba:today", "nba:upcoming", "nba:recent"], "NBA minute dates order live today upcoming recent final")
 check(orderingBatch.items.allSatisfy { $0.publishedAt != nil }, "NBA minute dates retain scheduled published dates")
 var missingStatus = validEvent; missingStatus.removeValue(forKey: "status")
 var unknownStatus = validEvent; unknownStatus["status"] = ["type": ["state": "unknown"]]
 for (event, label) in [(missingStatus, "missing"), (unknownStatus, "unknown"), (["id": "broken"], "malformed")] {
 let data = try JSONSerialization.data(withJSONObject: ["events": [event]])
 do { _ = try await FeedService(downloader: { _ in data }).fetch(channel: .nba, configuration: FeedConfiguration()); fatalError("accepted " + label + " NBA event") } catch { print("PASS: NBA " + label + " event throws for cache preservation") }
 }
 let mixedData = try JSONSerialization.data(withJSONObject: ["events": [validEvent, ["id": "broken"], missingStatus]])
 let mixedBatch = try await FeedService(downloader: { _ in mixedData }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(mixedBatch.items.count == 1 && mixedBatch.warning?.contains("2 malformed") == true, "NBA malformed individual events warn with count")
 var eastern = Calendar(identifier: .gregorian); eastern.timeZone = TimeZone(identifier: "America/New_York")!
 let dayFormatter = DateFormatter(); dayFormatter.calendar = eastern; dayFormatter.timeZone = eastern.timeZone; dayFormatter.dateFormat = "yyyyMMdd"
 check(mixedBatch.warning?.contains(dayFormatter.string(from: Date())) == true, "NBA malformed warning identifies affected date")
 let nbaBatch = try await FeedService(downloader: { url in
 check(url.absoluteString.contains("scoreboard?dates=") && url.absoluteString.hasSuffix("&limit=100") && !URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "dates" }!.value!.contains("-"), "NBA supported daily URL")
 return Data(nbaJSON.utf8)
 }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(nbaBatch.items.first?.title == "LAL 112 · BOS 108", "NBA score title")
 check(nbaBatch.items.first?.excerpt.contains("4:12") == true && nbaBatch.items.first?.excerpt.contains("REB 35") == true, "NBA live clock and stats")
 check(nbaBatch.items.first?.metric == "LIVE", "NBA live status")
 for (state, expected) in [("pre","SCHEDULED"),("post","FINAL")] {
 let data = Data(nbaJSON.replacingOccurrences(of: "\"in\"", with: "\"" + state + "\"").utf8)
 let batch = try await FeedService(downloader: { _ in data }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(batch.items.first?.metric == expected, "NBA " + expected)
 if state == "pre" { check(batch.items.first?.title == "LAL at BOS", "NBA scheduled matchup") }
 }
 let fallbackNBA = try await FeedService(downloader: { url in
 let dates = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "dates" }!.value!
 if dates.contains("-") { throw FeedError.message("The source returned HTTP 400. Try again later.") }
 check(dates.count == 8, "NBA fallback uses one date")
 return Data(nbaJSON.utf8)
 }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(fallbackNBA.items.count == 1, "NBA daily coverage deduplicates games")
 var dayRequest = 0
 let partialNBA = try await FeedService(downloader: { _ in
 dayRequest += 1
 if dayRequest == 1 { throw FeedError.message("one day unavailable") }
 return Data(nbaJSON.utf8)
 }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(dayRequest == 3 && partialNBA.items.count == 1 && partialNBA.warning != nil, "NBA three-day coverage preserves partial results")
 do { _ = try await FeedService(downloader: { _ in throw FeedError.message("offline") }).fetch(channel: .nba, configuration: FeedConfiguration()); fatalError("all-day failure accepted") } catch { print("PASS: NBA all-day failure throws for cache preservation") }
 let emptyNBA = try await FeedService(downloader: { _ in Data("{\"events\":[]}".utf8) }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(emptyNBA.items.first?.title == "No NBA games scheduled", "NBA empty coverage")
 do { _ = try await FeedService(downloader: { _ in Data("{}".utf8) }).fetch(channel: .nba, configuration: FeedConfiguration()); fatalError("malformed NBA accepted") } catch { print("PASS: malformed NBA rejected") }
 var customConfig = FeedConfiguration(); customConfig.customStations = [CustomStation(id:"demo",title:"Demo",feedURLs:["https://one.test/feed","https://two.test/feed"],keywords:"quantum,robot")]
 let filtered = try await FeedService(downloader: { url in Data(("<rss><channel><item><title>Quantum idea</title><link>https://example.test/" + url.host! + "</link></item><item><title>Other</title><link>https://example.test/other</link></item></channel></rss>").utf8) }).fetch(channel: .station("demo"), configuration: customConfig)
 check(filtered.items.count == 2 && filtered.items.allSatisfy { $0.title == "Quantum idea" }, "custom multiple sources and OR keywords")
 var aiConfig = FeedConfiguration(); aiConfig.aiSourceIDs = ["nvidia"]
 let broad = try await FeedService(downloader: { _ in Data("<rss><channel><item><title>AI progress</title><link>https://example.test/ai</link></item><item><title>Train stations</title><link>https://example.test/train</link></item></channel></rss>".utf8) }).fetch(channel: .ai, configuration: aiConfig)
 check(broad.items.count == 1, "broad AI source filters word boundaries")
 let emptyFeed = try await FeedService(downloader: { _ in Data("<rss><channel/></rss>".utf8) }).fetch(channel: .ai, configuration: aiConfig)
 check(emptyFeed.items.isEmpty && emptyFeed.warning == nil, "valid empty feed succeeds")
 aiConfig.aiSourceIDs = ["unknown"]
 do { _ = try await FeedService(downloader: { _ in fatalError("invalid source requested") }).fetch(channel: .ai, configuration: aiConfig); fatalError("unknown source accepted") } catch { print("PASS: invalid source rejected") }
 let researchXML = "<rss><channel>" + (0..<35).map { "<item><title>AI paper</title><link>https://arxiv.org/abs/ai" + String($0) + "</link><category>cs.AI</category></item>" }.joined() + "<item><title>Physics paper</title><link>https://arxiv.org/abs/physics</link><category>physics.optics</category></item></channel></rss>"
 let researchBatch = try await FeedService(downloader: { _ in Data(researchXML.utf8) }).fetch(channel: .research, configuration: FeedConfiguration())
 check(researchBatch.items.prefix(3).contains { $0.title == "Physics paper" }, "research interleaves selected topics")
 var mixedConfig = FeedConfiguration(); mixedConfig.aiSourceIDs = ["openai","deepmind"]
 let mixed = try await FeedService(downloader: { url in
 if url.host == "openai.com" { throw FeedError.message("fixture failure") }
 return Data("<rss><channel><item><title>Available</title><link>https://example.test/available</link></item></channel></rss>".utf8)
 }).fetch(channel: .ai, configuration: mixedConfig)
 check(mixed.items.count == 1 && mixed.warning?.contains("OpenAI") == true, "partial source failure preserves available feed")
 let manyService = FeedService(downloader: { url in
 var xml = "<rss><channel>"
 for index in 0..<35 { xml += "<item><title>Story</title><link>https://\(url.host!)/story/\(index)</link></item>" }
 xml += "</channel></rss>"
 return Data(xml.utf8)
 })
 let many = try await manyService.fetch(channel: .ai, configuration: mixedConfig)
 check(many.items.count == 30 && many.items.prefix(2).contains { $0.source == "Google DeepMind · Company" }, "multi-source edition interleaves before cap")
 let cancelledGame = nbaJSON.replacingOccurrences(of: "\"state\":\"in\"", with: "\"state\":\"pre\",\"name\":\"STATUS_CANCELED\"")
 let cancelledBatch = try await FeedService(downloader: { _ in Data(cancelledGame.utf8) }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(cancelledBatch.items.first?.metric == "CANCELED", "NBA preserves canceled status")
 let noStats = nbaJSON.replacingOccurrences(of: ",\"statistics\":[{\"name\":\"rebounds\",\"abbreviation\":\"REB\",\"displayValue\":\"35\"}]", with: "")
 let noStatsBatch = try await FeedService(downloader: { _ in Data(noStats.utf8) }).fetch(channel: .nba, configuration: FeedConfiguration())
 check(noStatsBatch.items.first?.title == "LAL 112 · BOS 108", "NBA missing stats remains readable")
 let rss = """
 <rss version="2.0"><channel><item><title>A &amp; B</title><link>https://example.com/a</link><description><![CDATA[<p>Hello &amp; world</p>]]></description><pubDate>Tue, 13 Oct 2026 10:00:00 GMT</pubDate></item><item><title>Unsafe</title><link>javascript:alert(1)</link></item></channel></rss>
 """
 let items = try FeedParser.parse(Data(rss.utf8), source: "Fixture")
 check(items.count == 1, "RSS rejects unsafe links")
 check(items.first?.excerpt == "Hello & world", "RSS HTML and entities")
 check(items.first?.publishedAt != nil, "RSS date")
 let credentialFeed = "<rss><channel><item><title>Unsafe credential URL</title><link>https://user:secret@example.test/article</link></item></channel></rss>"
 let credentialItems = try FeedParser.parse(Data(credentialFeed.utf8), source: "Unsafe")
 check(credentialItems.isEmpty, "RSS rejects credential links")
 let atom = """
 <feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Atom</title><link rel="self" href="https://example.com/feed"/><link rel="alternate" href="https://example.com/article"/><summary>Summary</summary><updated>2026-10-14T01:02:03Z</updated></entry></feed>
 """
 let atomItems = try FeedParser.parse(Data(atom.utf8), source: "Atom")
 check(atomItems.first?.url.absoluteString == "https://example.com/article", "Atom alternate link")
 check(atomItems.first?.publishedAt != nil, "Atom date")
 let xhtml = "<feed><entry><title>Nested</title><link href=\"https://example.com/xhtml\"/><content type=\"xhtml\"><div><p>First paragraph</p><p>Second paragraph</p></div></content></entry></feed>"
 let nested = try FeedParser.parse(Data(xhtml.utf8), source: "Nested")
 check(nested.first?.excerpt == "First paragraph Second paragraph", "XHTML preserves paragraph separation")
 check(FeedParser.clean("arXiv:123v1 Announce Type: new Abstract: Real abstract") == "Real abstract", "arXiv boilerplate removed")
 do { _ = try FeedParser.parse(Data("<rss><channel>".utf8), source: "Broken"); fatalError("malformed XML accepted") } catch { print("PASS: malformed XML rejected") }
 let emptySummary = "<feed><entry><title>Fallback</title><link href=\"https://example.com/fallback\"/><summary>  </summary><content>Useful content</content></entry></feed>"
 let fallbackItems = try FeedParser.parse(Data(emptySummary.utf8), source: "Fallback")
 check(fallbackItems.first?.excerpt == "Useful content", "empty summary falls back to content")
 let cancelledService = FeedService(downloader: { _ in throw CancellationError() })
 do { _ = try await cancelledService.fetch(channel: .ai, configuration: FeedConfiguration()); fatalError("cancellation swallowed") }
 catch is CancellationError { print("PASS: source cancellation propagates") }
 catch { fatalError("source cancellation changed to \(error)") }
 let lateService = FeedService(downloader: { _ in withUnsafeCurrentTask { $0?.cancel() }; return Data(rss.utf8) })
 let lateTask = Task { try await lateService.fetch(channel: .custom, configuration: FeedConfiguration(customFeedURL: "https://example.com/feed")) }
 do { _ = try await lateTask.value; fatalError("cancelled response returned") }
 catch is CancellationError { print("PASS: cancellation after download discards response") }
 let earlyTask = Task { () throws -> FeedBatch in
 withUnsafeCurrentTask { $0?.cancel() }
 return try await FeedService(downloader: { _ in fatalError("cancelled task started request") }).fetch(channel: .github, configuration: FeedConfiguration())
 }
 do { _ = try await earlyTask.value; fatalError("pre-cancelled task returned") }
 catch is CancellationError { print("PASS: cancellation prevents request") }
 let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
 defer { try? FileManager.default.removeItem(at: directory) }
 let cache = RadioCache(directory: directory)
 let batch = FeedBatch(items: items, fetchedAt: Date(), warning: nil)
 try cache.save(batch, channel: .github, configuration: FeedConfiguration())
 check(cache.load(channel: .github, configuration: FeedConfiguration())?.items == items, "cache roundtrip")
 check(cache.load(channel: .github, configuration: FeedConfiguration(githubQuery: "swift")) != nil, "cache ignores legacy query")
 try cache.save(batch, channel: .custom, configuration: FeedConfiguration(customFeedURL: "https://example.com/a"))
 check(cache.load(channel: .custom, configuration: FeedConfiguration(customFeedURL: "https://example.com/b")) == nil, "cache URL isolation")
 do { _ = try await FeedService().fetch(channel: .custom, configuration: FeedConfiguration(customFeedURL: "http://example.com")); fatalError("unsafe feed accepted") } catch { print("PASS: custom HTTPS validation") }
 try cache.save(batch, channel: .ai, configuration: FeedConfiguration())
 check(cache.load(channel: .ai, configuration: FeedConfiguration(githubQuery: "different", customFeedURL: "https://other.test"))?.items == items, "cache ignores irrelevant configuration")
 var periodConfig = FeedConfiguration(); periodConfig.githubPeriod = .weekly
 check(cache.load(channel: .github, configuration: periodConfig) == nil, "cache isolates GitHub periods")
 var selectedConfig = FeedConfiguration(); selectedConfig.aiSourceIDs = ["openai"]
 check(cache.load(channel: .ai, configuration: selectedConfig) == nil, "cache isolates AI selections")
 try cache.save(batch, channel: .station("demo"), configuration: customConfig)
 customConfig.customStations[0].keywords = "different"
 check(cache.load(channel: .station("demo"), configuration: customConfig) == nil, "cache isolates station keywords")
 try cache.save(batch, channel: .research, configuration: FeedConfiguration())
 var researchConfig = FeedConfiguration(); researchConfig.researchTopics = ["quant-ph"]
 check(cache.load(channel: .research, configuration: researchConfig) == nil, "cache isolates research selections")
 let encodedChannel = try JSONEncoder().encode(RadioChannel.station("demo"))
 check(String(data: encodedChannel, encoding: .utf8) == "\"custom:demo\"", "dynamic channel encodes as string")
 for name in ["deepmind", "huggingface", "arxiv"] {
 let fixture = URL(fileURLWithPath: "work/\(name).xml")
 if let data = try? Data(contentsOf: fixture) {
 let parsed = try FeedParser.parse(data, source: name)
 check(!parsed.isEmpty, "\(name) downloaded fixture parses")
 check(parsed.allSatisfy { $0.excerpt.count <= 340 && $0.publishedAt != nil }, "\(name) dates and excerpt limits")
 }
 }
 if CommandLine.arguments.contains("--live") {
 for channel in RadioChannel.allCases {
 do { let result = try await FeedService().fetch(channel: channel, configuration: FeedConfiguration(customFeedURL: "https://deepmind.google/blog/rss.xml")); print("LIVE \(channel.rawValue): \(result.items.count), warning: \(result.warning ?? "none")") } catch { print("LIVE \(channel.rawValue) FAILED: \(error.localizedDescription)") }
 }
 }
 }
}
