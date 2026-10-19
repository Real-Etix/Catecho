import Foundation
import SwiftUI

@main struct DiscoveryModelTests {
    @MainActor static func wait(_ predicate: () -> Bool) async {
        for _ in 0..<1000 { if predicate() { return }; try? await Task.sleep(nanoseconds: 1_000_000) }
        fatalError("Discovery model timed out")
    }
    @MainActor static func main() async {
        let first = DiscoveredFeed(url: URL(string: "https://example.test/feed")!, title: "News")
        let second = DiscoveredFeed(url: URL(string: "https://example.test/research.xml")!, title: "Research")
        let model = FeedDiscoveryModel(resolve: { _ in [first, second] })
        await model.search("example.test", delay: 0)
        precondition(model.selectedURLs(for: "example.test") == [first.id])
        model.toggle(second)
        precondition(model.selectedURLs(for: "example.test") == [first.id, second.id])
        precondition(model.selectedURLs(for: "new.example.test") == nil, "Changed input cannot reuse stale results")
        model.toggle(first); model.toggle(second)
        precondition(model.selectedURLs(for: "example.test") == nil, "Every input needs a selected verified feed")
        print("PASS discovery model: automatic first choice, multiple feeds, readiness tied to input")

        let offline = FeedDiscoveryModel(resolve: { _ in throw FeedError.message("offline") })
        await offline.search(first.id, knownURLs: [first.id], delay: 0)
        precondition(offline.selectedURLs(for: first.id) == [first.id], "Existing saved feed remains editable offline")
        await offline.search("example.test", delay: 0)
        precondition(!offline.isSearching && offline.groups.first?.error == "offline" && offline.selectedURLs(for: "example.test") == nil)
        print("PASS discovery model: known feeds work offline; failed discovery cannot be saved")

        let page = DiscoveredFeed(url: URL(string: "https://example.test/news")!, title: "News page", kind: .webpage)
        let web = FeedDiscoveryModel(resolve: { _ in [page] })
        await web.search("example.test/news", delay: 0)
        precondition(web.selectedSources(for: "example.test/news")?.first?.kind == .webpage)
        await offline.search(page.id, knownWebpageURLs: [page.id], delay: 0)
        precondition(offline.selectedSources(for: page.id)?.first?.kind == .webpage)
        print("PASS discovery model: webpage mode preserved through selection and offline editing")

        var pending: [String: CheckedContinuation<[DiscoveredFeed], Error>] = [:]
        let changing = FeedDiscoveryModel(resolve: { input in try await withCheckedThrowingContinuation { pending[input] = $0 } })
        let old = Task { await changing.search("old.example.test", delay: 0) }
        await wait { pending["old.example.test"] != nil }
        let new = Task { await changing.search("new.example.test", delay: 0) }
        await wait { pending["new.example.test"] != nil }
        pending["new.example.test"]!.resume(returning: [second]); await new.value
        pending["old.example.test"]!.resume(returning: [first]); await old.value
        precondition(changing.selectedURLs(for: "new.example.test") == [second.id])
        let cancel = Task { await changing.search("cancel.example.test", delay: 0) }
        await wait { pending["cancel.example.test"] != nil }
        changing.cancel(); cancel.cancel()
        pending["cancel.example.test"]!.resume(returning: [first]); await cancel.value
        precondition(changing.groups.isEmpty && !changing.isSearching)
        print("PASS discovery model: late and cancelled results cannot overwrite current input")
    }
}
