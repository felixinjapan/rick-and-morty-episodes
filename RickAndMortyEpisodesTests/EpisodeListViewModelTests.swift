import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list view model")
struct EpisodeListViewModelTests {
    private func makeViewModel(
        api: StubAPI = threePageAPI(),
        store: FileEpisodeStore = .temporary(),
        now: Date = fixedDate
    ) -> EpisodeListViewModel {
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate })
        return EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { now })
    }

    @Test("Without a cache, pages load one at a time until the end is reached")
    func pagesUntilEnd() async throws {
        let store = FileEpisodeStore.temporary()
        let viewModel = makeViewModel(store: store)

        await viewModel.start()
        #expect(viewModel.footer == .loading(page: 1))

        await viewModel.loadNextPage()
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.footer == .loading(page: 2))
        // Each loaded page is saved, and "Last updated" is the time page 1 was fetched.
        #expect(try await store.load() == EpisodeSnapshot(episodes: viewModel.episodes, nextPage: 2, refreshedAt: fixedDate))
        #expect(viewModel.lastRefreshed == fixedDate)

        await viewModel.loadNextPage()
        await viewModel.loadNextPage()
        #expect(viewModel.episodes.map(\.id) == Array(1...45))
        #expect(viewModel.footer == .endReached(count: 45))
        #expect(try await store.load() == EpisodeSnapshot(episodes: viewModel.episodes, nextPage: nil, refreshedAt: fixedDate))
    }

    @Test("Reaching the end doesn't trigger more requests")
    func noRequestsAfterEnd() async {
        let api = threePageAPI()
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        for _ in 0..<5 { await viewModel.loadNextPage() }
        #expect(await api.requestedPages == [1, 2, 3])
    }

    @Test("Simultaneous triggers load a page only once")
    func duplicateTriggersAreIgnored() async {
        let api = threePageAPI()
        let viewModel = makeViewModel(api: api)
        await viewModel.start()

        async let first: Void = viewModel.loadNextPage()
        async let second: Void = viewModel.loadNextPage()
        _ = await (first, second)

        #expect(await api.requestedPages == [1])
        #expect(viewModel.episodes.count == 20)
    }

    @Test("A failed page shows an error and can be retried")
    func pageFailureAndRetry() async {
        let api = threePageAPI()
        await api.setPage(2, .failure(APIError.offline))
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()

        #expect(viewModel.footer == .failed(message: EpisodeError.offline.userMessage))
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.emptyListError == nil)

        await api.setPage(2, .success(.make(ids: 21...40, pageCount: 3, hasNextPage: true)))
        await viewModel.loadNextPage()
        #expect(viewModel.episodes.count == 40)
        #expect(viewModel.footer == .loading(page: 3))
    }

    @Test("A failed first page is shown full screen instead of in the footer, and can be retried")
    func firstPageFailureAndRetry() async {
        let api = threePageAPI()
        await api.setPage(1, .failure(APIError.offline))
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        await viewModel.loadNextPage()

        #expect(viewModel.emptyListError == EpisodeError.offline.userMessage)
        #expect(viewModel.footer == .none)

        await api.setPage(1, .success(.make(ids: 1...20, pageCount: 3, hasNextPage: true)))
        await viewModel.loadNextPage()
        #expect(viewModel.emptyListError == nil)
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.footer == .loading(page: 2))
    }

    @Test("Fresh cached content is shown at once, without network requests")
    func freshCache() async throws {
        let api = threePageAPI()
        let cached = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], refreshedAt: fixedDate)
        let viewModel = makeViewModel(api: api, store: try await .temporary(containing: cached), now: fixedDate.addingTimeInterval(60))

        await viewModel.start()

        #expect(viewModel.episodes.map(\.id) == [1, 2])
        #expect(viewModel.footer == .endReached(count: 2))
        #expect(viewModel.lastRefreshed == fixedDate)
        #expect(await api.requestedPages.isEmpty)
    }

    @Test("A partly loaded cache continues paging where it stopped")
    func partialCacheContinuesPaging() async throws {
        let api = threePageAPI()
        let cached = EpisodeSnapshot(episodes: (1...20).map(Episode.make), nextPage: 2, refreshedAt: fixedDate)
        let viewModel = makeViewModel(api: api, store: try await .temporary(containing: cached))

        await viewModel.start()
        #expect(viewModel.footer == .loading(page: 2))

        await viewModel.loadNextPage()
        #expect(viewModel.episodes.map(\.id) == Array(1...40))
        #expect(await api.requestedPages == [2])
    }

    @Test("Stale cached content is shown, then refreshed from page 1")
    func staleCache() async throws {
        let api = threePageAPI()
        let cached = EpisodeSnapshot(episodes: (1...45).map(Episode.make), refreshedAt: fixedDate)
        let viewModel = makeViewModel(api: api, store: try await .temporary(containing: cached), now: fixedDate.addingTimeInterval(7200))

        await viewModel.start()

        #expect(viewModel.episodes.map(\.id) == Array(1...20))
        #expect(viewModel.footer == .loading(page: 2))
        #expect(viewModel.refreshError == nil)
        #expect(await api.requestedPages == [1])
    }

    @Test("A failed refresh keeps the cached content and shows a banner")
    func failedRefreshKeepsContent() async throws {
        let api = StubAPI(pages: [1: .failure(APIError.offline)])
        let cached = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        let viewModel = makeViewModel(api: api, store: try await .temporary(containing: cached))

        await viewModel.start()
        await viewModel.refresh()

        #expect(viewModel.episodes.map(\.id) == [1])
        #expect(viewModel.refreshError == EpisodeError.offline.userMessage)
        #expect(viewModel.footer == .endReached(count: 1))
    }

    @Test("Pull-to-refresh starts the list again from a fresh page 1")
    func refreshStartsFromFirstPage() async {
        let api = threePageAPI()
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()
        #expect(viewModel.episodes.count == 40)

        await viewModel.refresh()

        #expect(viewModel.episodes.map(\.id) == Array(1...20))
        #expect(viewModel.footer == .loading(page: 2))
        #expect(await api.requestedPages == [1, 2, 1])
    }

    @Test("Returning to the foreground picks up data saved by a background refresh")
    func foregroundPicksUpBackgroundData() async throws {
        let store = try await FileEpisodeStore.temporary(containing: EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate))
        let viewModel = makeViewModel(store: store)
        await viewModel.start()

        let newer = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], refreshedAt: fixedDate.addingTimeInterval(60))
        try await store.save(newer)
        await viewModel.refreshIfNeeded()

        #expect(viewModel.episodes.count == 2)
        #expect(viewModel.lastRefreshed == newer.refreshedAt)
    }

    @Test("A fresh background snapshot clears an earlier refresh error")
    func foregroundSnapshotClearsRefreshError() async throws {
        let api = StubAPI(pages: [1: .failure(APIError.offline)])
        let store = try await FileEpisodeStore.temporary(containing: EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate))
        let viewModel = makeViewModel(api: api, store: store)
        await viewModel.start()
        await viewModel.refresh()
        #expect(viewModel.refreshError != nil)

        let newer = EpisodeSnapshot(episodes: [.make(id: 2)], refreshedAt: fixedDate.addingTimeInterval(60))
        try await store.save(newer)
        await viewModel.refreshIfNeeded()

        #expect(viewModel.episodes == newer.episodes)
        #expect(viewModel.lastRefreshed == newer.refreshedAt)
        #expect(viewModel.refreshError == nil)
        #expect(await api.requestedPages == [1])
    }

    @Test("A cache write failure does not disable future foreground refreshes")
    func failedBootstrapSaveStillTracksFreshness() async throws {
        let api = threePageAPI()
        let repository = DefaultEpisodeRepository(api: api, store: try .unwritable(), now: { fixedDate })
        var currentDate = fixedDate
        let viewModel = EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { currentDate })
        await viewModel.start()
        for _ in 0..<3 { await viewModel.loadNextPage() }
        #expect(viewModel.episodes.count == 45)
        #expect(viewModel.lastRefreshed == fixedDate)

        currentDate = fixedDate.addingTimeInterval(7200)
        await viewModel.refreshIfNeeded()
        #expect(await api.requestedPages.filter { $0 == 1 }.count == 2)
    }

    @Test("Cancelling the final page's footer does not discard the completed cache")
    func cancelledFinalPageStillPersists() async throws {
        let api = threePageAPI()
        let gate = Gate()
        await api.holdPage(3, until: gate)
        let store = FileEpisodeStore.temporary()
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate })
        let viewModel = EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { fixedDate })
        await viewModel.start()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()
        let finalPage = Task { await viewModel.loadNextPage() }
        while !(await api.requestedPages.contains(3)) { await Task.yield() }
        finalPage.cancel()
        await gate.open()
        await finalPage.value

        #expect(viewModel.episodes.count == 45)
        #expect(try await store.load()?.episodes.count == 45)
        #expect(viewModel.lastRefreshed == fixedDate)
    }

    @Test("Returning to the app rebuilds the list only when it replaced rows the user had loaded")
    func listIdentityOnReturn() async {
        let repository = DefaultEpisodeRepository(api: threePageAPI(), store: .temporary(), now: { fixedDate })
        var currentDate = fixedDate
        let viewModel = EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { currentDate })
        await viewModel.start()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()
        #expect(viewModel.episodes.count == 40)

        // Back within the hour: nothing changes.
        await viewModel.refreshIfNeeded()
        #expect(viewModel.listIdentity == 0)

        // Back after two hours: a fresh page 1 replaces the 40 loaded rows.
        currentDate = fixedDate.addingTimeInterval(7200)
        await viewModel.refreshIfNeeded()
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.listIdentity == 1)

        // Only page 1 loaded: a refresh updates it in place.
        await viewModel.refreshIfNeeded()
        #expect(viewModel.listIdentity == 1)

        // Page loads and pull-to-refresh never rebuild the list.
        await viewModel.loadNextPage()
        await viewModel.refresh()
        #expect(viewModel.listIdentity == 1)
    }

    @Test("The refresh indicator stays visible until every overlapping refresh finishes")
    func overlappingRefreshIndicator() async {
        let api = threePageAPI()
        let slowGate = Gate()
        await api.holdPage(1, until: slowGate)
        let repository = DefaultEpisodeRepository(api: api, store: .temporary())
        let viewModel = EpisodeListViewModel(repository: repository, staleInterval: 3600)

        let slow = Task { await viewModel.refresh() }
        while await api.requestedPages.isEmpty { await Task.yield() }

        // The second refresh isn't held, so it finishes while the first is still running.
        let openGate = Gate()
        await openGate.open()
        await api.holdPage(1, until: openGate)
        await viewModel.refresh()
        #expect(viewModel.isRefreshing)

        await slowGate.open()
        await slow.value
        #expect(!viewModel.isRefreshing)
        #expect(viewModel.episodes.count == 20)
    }
}
