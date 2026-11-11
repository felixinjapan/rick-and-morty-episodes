import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list model")
struct EpisodeListModelTests {
    private func makeModel(
        api: StubAPI = threePageAPI(),
        store: RecordingStore = RecordingStore(),
        now: Date = fixedDate
    ) -> EpisodeListModel {
        let repository = EpisodeRepository(api: api, store: store, now: { fixedDate })
        return EpisodeListModel(repository: repository, staleInterval: 3600, now: { now })
    }

    @Test("Without a cache, pages load one at a time until the end is reached")
    func pagesUntilEnd() async {
        let store = RecordingStore()
        let model = makeModel(store: store)

        await model.start()
        #expect(model.footer == .loading(page: 1))

        await model.loadNextPage()
        #expect(model.episodes.count == 20)
        #expect(model.footer == .loading(page: 2))

        await model.loadNextPage()
        await model.loadNextPage()
        #expect(model.episodes.map(\.id) == Array(1...45))
        #expect(model.footer == .endReached(count: 45))

        // The fully loaded list is saved for next launch, and the timestamp is shown.
        #expect(await store.snapshot?.episodes.count == 45)
        #expect(model.lastRefreshed == fixedDate)
    }

    @Test("Reaching the end doesn't trigger more requests")
    func noRequestsAfterEnd() async {
        let api = threePageAPI()
        let model = makeModel(api: api)
        await model.start()
        for _ in 0..<5 { await model.loadNextPage() }
        #expect(await api.requestedPages == [1, 2, 3])
    }

    @Test("Simultaneous triggers load a page only once")
    func duplicateTriggersAreIgnored() async {
        let api = threePageAPI()
        let model = makeModel(api: api)
        await model.start()

        async let first: Void = model.loadNextPage()
        async let second: Void = model.loadNextPage()
        _ = await (first, second)

        #expect(await api.requestedPages == [1])
        #expect(model.episodes.count == 20)
    }

    @Test("A failed page shows an error and can be retried")
    func pageFailureAndRetry() async {
        let api = threePageAPI()
        await api.setPage(2, .failure(APIError.offline))
        let model = makeModel(api: api)
        await model.start()
        await model.loadNextPage()
        await model.loadNextPage()

        #expect(model.footer == .failed(message: APIError.offline.userMessage))
        #expect(model.episodes.count == 20)

        await api.setPage(2, .success(.make(ids: 21...40, pageCount: 3, hasNextPage: true)))
        await model.retryLoadingPage()
        #expect(model.episodes.count == 40)
        #expect(model.footer == .loading(page: 3))
    }

    @Test("Fresh cached content is shown at once, without network requests")
    func freshCache() async {
        let api = threePageAPI()
        let cached = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], refreshedAt: fixedDate)
        let model = makeModel(api: api, store: RecordingStore(snapshot: cached), now: fixedDate.addingTimeInterval(60))

        await model.start()

        #expect(model.episodes.map(\.id) == [1, 2])
        #expect(model.footer == .endReached(count: 2))
        #expect(model.lastRefreshed == fixedDate)
        #expect(await api.requestedPages.isEmpty)
    }

    @Test("Stale cached content is shown, then refreshed")
    func staleCache() async {
        let cached = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        let model = makeModel(store: RecordingStore(snapshot: cached), now: fixedDate.addingTimeInterval(7200))

        await model.start()

        #expect(model.episodes.count == 45)
        #expect(model.refreshError == nil)
    }

    @Test("A failed refresh keeps the cached content and shows a banner")
    func failedRefreshKeepsContent() async {
        let api = StubAPI(pages: [1: .failure(APIError.offline)])
        let cached = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        let model = makeModel(api: api, store: RecordingStore(snapshot: cached))

        await model.start()
        await model.refresh()

        #expect(model.episodes.map(\.id) == [1])
        #expect(model.refreshError == APIError.offline.userMessage)
        #expect(model.footer == .endReached(count: 1))
    }

    @Test("Pull-to-refresh replaces a partially paged list with the complete one")
    func refreshReplacesPartialList() async {
        let model = makeModel()
        await model.start()
        await model.loadNextPage()
        #expect(model.episodes.count == 20)

        await model.refresh()

        #expect(model.episodes.map(\.id) == Array(1...45))
        #expect(model.footer == .endReached(count: 45))
    }

    @Test("Returning to the foreground picks up data saved by a background refresh")
    func foregroundPicksUpBackgroundData() async {
        let store = RecordingStore(snapshot: EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate))
        let model = makeModel(store: store)
        await model.start()

        let newer = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], refreshedAt: fixedDate.addingTimeInterval(60))
        await store.save(newer)
        await model.appDidBecomeActive()

        #expect(model.episodes.count == 2)
        #expect(model.lastRefreshed == newer.refreshedAt)
    }

    @Test("A fresh background snapshot clears an earlier refresh error")
    func foregroundSnapshotClearsRefreshError() async {
        let api = StubAPI(pages: [1: .failure(APIError.offline)])
        let store = RecordingStore(snapshot: EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate))
        let model = makeModel(api: api, store: store)
        await model.start()
        await model.refresh()
        #expect(model.refreshError != nil)

        let newer = EpisodeSnapshot(episodes: [.make(id: 2)], refreshedAt: fixedDate.addingTimeInterval(60))
        await store.save(newer)
        await model.appDidBecomeActive()

        #expect(model.episodes == newer.episodes)
        #expect(model.lastRefreshed == newer.refreshedAt)
        #expect(model.refreshError == nil)
        #expect(await api.requestedPages == [1])
    }
}
