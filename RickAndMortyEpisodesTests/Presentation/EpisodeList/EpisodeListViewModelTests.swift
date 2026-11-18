import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list view model")
struct EpisodeListViewModelTests {
    private func makeViewModel(
        api: StubAPI = makeThreePageAPI(),
        store: FileEpisodeStore = .makeTemporary(),
        now: Date = fixedDate
    ) -> EpisodeListViewModel {
        // One clock for both, so a fetch made "later" is stamped later.
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { now })
        return EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { now })
    }

    @Test("Without a cache, pages load one at a time until the end is reached")
    func pagesUntilEnd() async throws {
        let store = FileEpisodeStore.makeTemporary()
        let viewModel = makeViewModel(store: store)

        await viewModel.start()
        #expect(viewModel.footer == .loading(page: 1))

        await viewModel.loadNextPage()
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.footer == .loading(page: 2))
        #expect(try await store.load() == EpisodeSnapshot(
            episodes: viewModel.episodes, nextPage: 2, totalCount: 45, refreshedAt: fixedDate
        ))
        #expect(viewModel.lastRefreshedAt == fixedDate)

        await viewModel.loadNextPage()
        await viewModel.loadNextPage()
        #expect(viewModel.episodes.map(\.id) == Array(1...45))
        #expect(viewModel.footer == .endReached(count: 45))
        #expect(try await store.load() == EpisodeSnapshot(
            episodes: viewModel.episodes, nextPage: nil, totalCount: 45, refreshedAt: fixedDate
        ))
    }

    @Test("Reaching the end doesn't trigger more requests")
    func noRequestsAfterEnd() async {
        let api = makeThreePageAPI()
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        for _ in 0..<5 { await viewModel.loadNextPage() }
        #expect(await api.requestedPages == [1, 2, 3])
    }

    @Test("A long feed keeps pages in order and can continue loading")
    func longFeedKeepsPagesInOrder() async throws {
        let pageCount = 80
        let pageSize = 12
        let totalCount = 120_000
        let pages = Dictionary(uniqueKeysWithValues: (1...pageCount).map { page in
            let firstID = (page - 1) * pageSize + 1
            let result: Result<EpisodePage, any Error> = .success(
                .make(ids: firstID...(firstID + pageSize - 1), hasNextPage: true, totalCount: totalCount)
            )
            return (page, result)
        })
        let api = StubAPI(pages: pages)
        let store = FileEpisodeStore.makeTemporary()
        let viewModel = makeViewModel(api: api, store: store)
        await viewModel.start()

        for _ in 1...pageCount {
            await viewModel.loadNextPage()
        }

        #expect(await api.requestedPages == Array(1...pageCount))
        #expect(viewModel.episodes.map(\.id) == Array(1...(pageCount * pageSize)))
        #expect(viewModel.footer == .loading(page: pageCount + 1))
        #expect(try await store.load()?.episodes == viewModel.episodes)
    }

    @Test("A second trigger while a page is loading is ignored", .timeLimit(.minutes(1)))
    func duplicateTriggersAreIgnored() async {
        let api = makeThreePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let viewModel = makeViewModel(api: api)
        await viewModel.start()

        // Page 1 is held, so the second trigger is sure to arrive while it is loading.
        let first = Task { await viewModel.loadNextPage() }
        while await api.requestedPages.isEmpty { await Task.yield() }
        await viewModel.loadNextPage()
        await gate.open()
        await first.value

        #expect(await api.requestedPages == [1])
        #expect(viewModel.episodes.count == 20)
    }

    @Test("A failed page shows an error and can be retried")
    func pageFailureAndRetry() async {
        let api = makeThreePageAPI()
        await api.setPage(2, .failure(APIError.offline))
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()

        #expect(viewModel.footer == .failed(message: RepositoryError.offline.userMessage))
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.emptyListErrorMessage == nil)

        await api.setPage(2, .success(.make(ids: 21...40, hasNextPage: true)))
        await viewModel.loadNextPage()
        #expect(viewModel.episodes.count == 40)
        #expect(viewModel.footer == .loading(page: 3))
    }

    @Test("A cancelled page load shows no error and can be loaded again")
    func cancelledPageShowsNoError() async {
        let api = makeThreePageAPI()
        await api.setPage(2, .failure(CancellationError()))
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()

        #expect(viewModel.footer == .loading(page: 2))
        #expect(viewModel.emptyListErrorMessage == nil)
        #expect(viewModel.episodes.count == 20)

        await api.setPage(2, .success(.make(ids: 21...40, hasNextPage: true)))
        await viewModel.loadNextPage()
        #expect(viewModel.episodes.count == 40)
    }

    @Test("A failed first page is shown full screen instead of in the footer, and can be retried")
    func firstPageFailureAndRetry() async {
        let api = makeThreePageAPI()
        await api.setPage(1, .failure(APIError.offline))
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        await viewModel.loadNextPage()

        #expect(viewModel.emptyListErrorMessage == RepositoryError.offline.userMessage)
        #expect(viewModel.footer == .none)

        await api.setPage(1, .success(.make(ids: 1...20, hasNextPage: true)))
        await viewModel.loadNextPage()
        #expect(viewModel.emptyListErrorMessage == nil)
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.footer == .loading(page: 2))
    }

    @Test("Fresh cached content is shown at once, without network requests")
    func freshCache() async throws {
        let api = makeThreePageAPI()
        let cached = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], refreshedAt: fixedDate)
        let viewModel = makeViewModel(
            api: api, store: try await .makeTemporary(containing: cached), now: fixedDate.addingTimeInterval(60)
        )

        await viewModel.start()

        #expect(viewModel.episodes.map(\.id) == [1, 2])
        #expect(viewModel.footer == .endReached(count: 2))
        #expect(viewModel.lastRefreshedAt == fixedDate)
        #expect(await api.requestedPages.isEmpty)
    }

    @Test("A partly loaded cache continues paging where it stopped")
    func partialCacheContinuesPaging() async throws {
        let api = makeThreePageAPI()
        let cached = EpisodeSnapshot(episodes: (1...20).map(Episode.make), nextPage: 2, refreshedAt: fixedDate)
        let viewModel = makeViewModel(api: api, store: try await .makeTemporary(containing: cached))

        await viewModel.start()
        #expect(viewModel.footer == .loading(page: 2))

        await viewModel.loadNextPage()
        #expect(viewModel.episodes.map(\.id) == Array(1...40))
        #expect(await api.requestedPages == [2])
    }

    @Test("Stale cached content is shown, then page 1 is refreshed and the cached pages after it stay")
    func staleCache() async throws {
        let api = makeThreePageAPI()
        await api.setPage(1, .success(.make(ids: 101...120, hasNextPage: true)))
        let cached = EpisodeSnapshot(episodes: (1...45).map(Episode.make), refreshedAt: fixedDate)
        let viewModel = makeViewModel(
            api: api, store: try await .makeTemporary(containing: cached), now: fixedDate.addingTimeInterval(7200)
        )

        await viewModel.start()

        #expect(viewModel.episodes.map(\.id) == Array(101...120) + Array(21...45))
        #expect(viewModel.footer == .endReached(count: 45))
        #expect(viewModel.refreshErrorMessage == nil)
        #expect(await api.requestedPages == [1])
    }

    @Test("A failed refresh keeps the cached content and shows a banner until a refresh succeeds")
    func failedRefreshKeepsContent() async throws {
        let api = StubAPI(pages: [1: .failure(APIError.offline)])
        let cached = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        let viewModel = makeViewModel(
            api: api, store: try await .makeTemporary(containing: cached), now: fixedDate.addingTimeInterval(60)
        )

        await viewModel.start()
        await viewModel.refresh()

        #expect(viewModel.episodes.map(\.id) == [1])
        #expect(viewModel.refreshErrorMessage == RepositoryError.offline.userMessage)
        #expect(viewModel.footer == .endReached(count: 1))

        await api.setPage(1, .success(.make(ids: 1...20, hasNextPage: true)))
        await viewModel.refresh()
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.refreshErrorMessage == nil)
    }

    @Test("Loading another page keeps the refresh error while the list is still old")
    func pageLoadKeepsRefreshError() async throws {
        let api = makeThreePageAPI()
        await api.setPage(1, .failure(APIError.offline))
        let cached = EpisodeSnapshot(episodes: (1...20).map(Episode.make), nextPage: 2, refreshedAt: fixedDate)
        let viewModel = makeViewModel(api: api, store: try await .makeTemporary(containing: cached))
        await viewModel.start()
        await viewModel.refresh()
        try #require(viewModel.refreshErrorMessage == RepositoryError.offline.userMessage)

        await viewModel.loadNextPage()

        #expect(viewModel.episodes.count == 40)
        #expect(viewModel.refreshErrorMessage == RepositoryError.offline.userMessage)
    }

    @Test("Pull-to-refresh fetches a fresh page 1 and keeps the pages already loaded")
    func refreshKeepsLoadedPages() async throws {
        let api = makeThreePageAPI()
        let viewModel = makeViewModel(api: api)
        await viewModel.start()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()
        try #require(viewModel.episodes.count == 40)

        await viewModel.refresh()

        #expect(viewModel.episodes.map(\.id) == Array(1...40))
        #expect(viewModel.footer == .loading(page: 3))
        #expect(await api.requestedPages == [1, 2, 1])
    }

    @Test("A fresh background snapshot clears an earlier refresh error")
    func foregroundSnapshotClearsRefreshError() async throws {
        let api = StubAPI(pages: [1: .failure(APIError.offline)])
        let store = try await FileEpisodeStore.makeTemporary(
            containing: EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        )
        let viewModel = makeViewModel(api: api, store: store)
        await viewModel.start()
        await viewModel.refresh()
        try #require(viewModel.refreshErrorMessage != nil)

        let newer = EpisodeSnapshot(episodes: [.make(id: 2)], refreshedAt: fixedDate.addingTimeInterval(60))
        try await store.save(newer)
        await viewModel.refreshIfNeeded()

        #expect(viewModel.episodes == newer.episodes)
        #expect(viewModel.lastRefreshedAt == newer.refreshedAt)
        #expect(viewModel.refreshErrorMessage == nil)
        #expect(await api.requestedPages == [1])
    }

    @Test("A cache write failure does not disable future foreground refreshes")
    func cacheWriteFailureKeepsRefreshing() async throws {
        let api = makeThreePageAPI()
        let repository = DefaultEpisodeRepository(api: api, store: try .makeUnwritable(), now: { fixedDate })
        var currentDate = fixedDate
        let viewModel = EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { currentDate })
        await viewModel.start()
        for _ in 0..<3 { await viewModel.loadNextPage() }
        try #require(viewModel.episodes.count == 45)
        try #require(viewModel.lastRefreshedAt == fixedDate)

        currentDate = fixedDate.addingTimeInterval(7200)
        await viewModel.refreshIfNeeded()
        #expect(await api.requestedPages.filter { $0 == 1 }.count == 2)
    }

    @Test("Cancelling the final page's footer does not discard the completed cache", .timeLimit(.minutes(1)))
    func cancelledFinalPageStillPersists() async throws {
        let api = makeThreePageAPI()
        let gate = Gate()
        await api.holdPage(3, until: gate)
        let store = FileEpisodeStore.makeTemporary()
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
        #expect(viewModel.lastRefreshedAt == fixedDate)
    }

    @Test("Returning to the app while a refresh is running doesn't start another", .timeLimit(.minutes(1)))
    func noDuplicateRefreshOnReturn() async throws {
        let api = makeThreePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let cached = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        let viewModel = makeViewModel(
            api: api, store: try await .makeTemporary(containing: cached), now: fixedDate.addingTimeInterval(7200)
        )

        // Launch with a stale cache starts a refresh; the app becomes active while it runs.
        let launch = Task { await viewModel.start() }
        while await api.requestedPages.isEmpty { await Task.yield() }
        await viewModel.refreshIfNeeded()

        #expect(await api.requestedPages == [1])
        await gate.open()
        await launch.value
        #expect(viewModel.episodes.count == 20)
    }

    @Test("Returning to the app rebuilds the list only when it replaced rows the user had loaded")
    func listIdentityOnReturn() async throws {
        let api = makeThreePageAPI()
        let repository = DefaultEpisodeRepository(api: api, store: .makeTemporary(), now: { fixedDate })
        var currentDate = fixedDate
        let viewModel = EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { currentDate })
        await viewModel.start()
        await viewModel.loadNextPage()
        await viewModel.loadNextPage()
        try #require(viewModel.episodes.count == 40)

        await viewModel.refreshIfNeeded()
        #expect(viewModel.listIdentity == 0)

        // Back after two hours, with fewer episodes than before: only the fresh page 1 is kept,
        // and it replaces the 40 loaded rows. (A catalogue of the same size keeps loaded rows.)
        await api.setPage(1, .success(.make(ids: 1...20, hasNextPage: true, totalCount: 44)))
        currentDate = fixedDate.addingTimeInterval(7200)
        await viewModel.refreshIfNeeded()
        #expect(viewModel.episodes.count == 20)
        #expect(viewModel.listIdentity == 1)

        await viewModel.refreshIfNeeded()
        #expect(viewModel.listIdentity == 1)

        await viewModel.loadNextPage()
        await viewModel.refresh()
        #expect(viewModel.listIdentity == 1)
    }

    @Test("The refresh indicator stays visible until every overlapping refresh finishes", .timeLimit(.minutes(1)))
    func overlappingRefreshIndicator() async {
        let api = makeThreePageAPI()
        let slowGate = Gate()
        await api.holdPage(1, until: slowGate)
        let repository = DefaultEpisodeRepository(api: api, store: .makeTemporary())
        let viewModel = EpisodeListViewModel(repository: repository, staleInterval: 3600)

        let slow = Task { await viewModel.refresh() }
        while await api.requestedPages.isEmpty { await Task.yield() }

        // The second refresh isn't held, so it finishes while the first is still running.
        await api.holdPage(1, until: nil)
        await viewModel.refresh()
        #expect(viewModel.isRefreshing)

        await slowGate.open()
        await slow.value
        #expect(viewModel.isRefreshing == false)
        #expect(viewModel.episodes.count == 20)
    }
}
