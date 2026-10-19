import Foundation
import SwiftUI

struct FeedDiscoveryGroup: Identifiable {
    let input: String
    let feeds: [DiscoveredFeed]
    let error: String?
    var id: String { input }
}

@MainActor final class FeedDiscoveryModel: ObservableObject {
    @Published private(set) var groups: [FeedDiscoveryGroup] = []
    @Published private(set) var isSearching = false
    @Published private(set) var error: String?
    @Published private(set) var selected: Set<String> = []
    private var searchedInput = ""
    private var generation = UUID()
    private let resolve: (String) async throws -> [DiscoveredFeed]

    init(resolve: @escaping (String) async throws -> [DiscoveredFeed] = { try await FeedDiscovery().discover($0) }) { self.resolve = resolve }

    func search(_ input: String, knownURLs: [String] = [], knownWebpageURLs: [String] = [], delay: UInt64 = 600_000_000) async {
        let request = UUID(); generation = request
        searchedInput = input; groups = []; selected = []; error = nil
        let lines = Self.lines(input)
        isSearching = !lines.isEmpty
        guard !lines.isEmpty else { return }
        guard lines.count <= 8 else { error = "Use up to 8 website links, one per line."; isSearching = false; return }
        do {
            if delay > 0 { try await Task.sleep(nanoseconds: delay) }
            for line in lines {
                try Task.checkCancellation()
                guard generation == request else { return }
                let result: FeedDiscoveryGroup
                do {
                    let feeds: [DiscoveredFeed]
                    if knownURLs.contains(line) || knownWebpageURLs.contains(line), let url = URL(string: line) {
                        feeds = [DiscoveredFeed(url: url, title: url.host ?? line, kind: knownWebpageURLs.contains(line) ? .webpage : .feed)]
                    } else { feeds = try await resolve(line) }
                    try Task.checkCancellation()
                    result = FeedDiscoveryGroup(input: line, feeds: feeds, error: feeds.isEmpty ? WebpageReader.unavailable : nil)
                } catch is CancellationError { throw CancellationError() }
                catch { try Task.checkCancellation(); result = FeedDiscoveryGroup(input: line, feeds: [], error: error.localizedDescription) }
                guard generation == request else { return }
                groups.append(result)
                if let first = result.feeds.first { selected.insert(first.id) }
            }
        } catch { /* Cancellation leaves no saveable result. */
            if generation == request { groups = []; selected = [] }
        }
        if generation == request { isSearching = false }
    }
    func cancel() {
        generation = UUID(); groups = []; selected = []; searchedInput = ""; isSearching = false; error = nil
    }
    func toggle(_ feed: DiscoveredFeed) {
        if selected.contains(feed.id) { selected.remove(feed.id) } else { selected.insert(feed.id) }
    }
    func selectedURLs(for input: String) -> [String]? { selectedSources(for: input)?.map { $0.url.absoluteString } }
    func selectedSources(for input: String) -> [DiscoveredFeed]? {
        guard input == searchedInput, !isSearching, error == nil, !groups.isEmpty,
              groups.count == Self.lines(input).count,
              groups.allSatisfy({ $0.error == nil && $0.feeds.contains { selected.contains($0.id) } }) else { return nil }
        var seen = Set<String>()
        let urls = groups.flatMap(\.feeds).filter { selected.contains($0.id) && seen.insert($0.id).inserted }
        return (1...8).contains(urls.count) ? urls : nil
    }
    private static func lines(_ input: String) -> [String] {
        var seen = Set<String>()
        return input.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
