import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Episode repository")
struct EpisodeRepositoryTests {
    @Test("Refresh makes one request and saves a fresh page 1 with the cached pages after it")
    func refreshKeepsCachedPagesWhenCatalogueIsUnchanged() async throws {
        let api = makeThreePageAPI()
        await api.setPage(1, .success(.make(ids: 101...120, hasNextPage: true)))
        let previous = EpisodeSnapshot(episodes: (1...45).map(Episode.make), totalCount: 45, refreshedAt: fixedDate)
        let store = try await FileEpisodeStore.makeTemporary(containing: previous)
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate.addingTimeInterval(60) })

        let snapshot = try await repository.refreshFirstPage()

        #expect(await api.requestedPages == [1])
        #expect(snapshot.episodes.map(\.id) == Array(101...120) + Array(21...45))
        #expect(snapshot.nextPage == nil)
        #expect(snapshot.refreshedAt == fixedDate.addingTimeInterval(60))
        #expect(try await store.load() == snapshot)
    }

    @Test("A bigger catalogue keeps the whole cached pages and loads the rest on scroll")
    func refreshWhenCatalogueGrew() async throws {
        let api = makeThreePageAPI()
        await api.setPage(1, .success(.make(ids: 1...20, hasNextPage: true, totalCount: 46)))
        let previous = EpisodeSnapshot(episodes: (1...45).map(Episode.make), totalCount: 45, refreshedAt: fixedDate)
        let store = try await FileEpisodeStore.makeTemporary(containing: previous)
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate.addingTimeInterval(60) })

        let snapshot = try await repository.refreshFirstPage()

        // The last cached page had 5 of 20 places filled, so the new episode lands on it: load it again.
        #expect(snapshot.episodes.map(\.id) == Array(1...40))
        #expect(snapshot.nextPage == 3)
        #expect(snapshot.totalCount == 46)
    }

    @Test("A smaller catalogue keeps only the new page 1")
    func refreshWhenCatalogueShrank() async throws {
        let api = makeThreePageAPI()
        await api.setPage(1, .success(.make(ids: 1...20, hasNextPage: true, totalCount: 44)))
        let previous = EpisodeSnapshot(episodes: (1...45).map(Episode.make), totalCount: 45, refreshedAt: fixedDate)
        let repository = DefaultEpisodeRepository(
            api: api, store: try await FileEpisodeStore.makeTemporary(containing: previous)
        )

        let snapshot = try await repository.refreshFirstPage()

        #expect(snapshot.episodes.map(\.id) == Array(1...20))
        #expect(snapshot.nextPage == 2)
    }

    // Tests that wait for a request in a loop have a time limit, so a regression fails instead of hanging.
    @Test("A page that arrives after a refresh doesn't overwrite the refreshed list", .timeLimit(.minutes(1)))
    func latePageAfterRefresh() async throws {
        let api = makeThreePageAPI()
        let store = FileEpisodeStore.makeTemporary()
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate })
        let first = try await repository.loadNextPage(after: nil)

        let gate = Gate()
        await api.holdPage(2, until: gate)
        let lateLoad = Task { try await repository.loadNextPage(after: first) }
        while !(await api.requestedPages.contains(2)) { await Task.yield() }
        await api.setPage(1, .success(.make(ids: 101...120, hasNextPage: true)))
        let refreshed = try await repository.refreshFirstPage()
        await gate.open()

        #expect(try await lateLoad.value == refreshed)
        #expect(try await store.load() == refreshed)
    }

    @Test("A failed refresh leaves the previous cache untouched")
    func failedRefreshKeepsCache() async throws {
        let api = makeThreePageAPI()
        await api.setPage(1, .failure(APIError.http(statusCode: 500)))
        let previous = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        let store = try await FileEpisodeStore.makeTemporary(containing: previous)
        let repository = DefaultEpisodeRepository(api: api, store: store)

        await #expect(throws: DataError.serverUnavailable) {
            try await repository.refreshFirstPage()
        }
        #expect(try await store.load() == previous)
    }

    @Test("A refresh cancelled before the response arrives saves nothing", .timeLimit(.minutes(1)))
    func cancelledRefreshSavesNothing() async throws {
        let api = makeThreePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let store = FileEpisodeStore.makeTemporary()
        let repository = DefaultEpisodeRepository(api: api, store: store)

        let refresh = Task { try await repository.refreshFirstPage() }
        while await api.requestedPages.isEmpty { await Task.yield() }
        refresh.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await refresh.value }
        #expect(try await store.load() == nil)
    }

    @Test("A refresh cancelled after the response arrived still saves page 1")
    func refreshCancelledAfterResponseStillSaves() async throws {
        let store = FileEpisodeStore.makeTemporary()
        let repository = DefaultEpisodeRepository(api: CancelsAfterResponseAPI(), store: store, now: { fixedDate })

        // Its own task, so the cancellation doesn't reach the test itself.
        let snapshot = try await Task { try await repository.refreshFirstPage() }.value

        #expect(snapshot.episodes.map(\.id) == Array(1...20))
        #expect(try await store.load() == snapshot)
    }

    @Test("An unreadable cache is treated as no cache")
    func corruptCache() async throws {
        let fileURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        try Data("not json".utf8).write(to: fileURL)
        let repository = DefaultEpisodeRepository(api: StubAPI(), store: FileEpisodeStore(fileURL: fileURL))
        #expect(await repository.loadCurrentSnapshot() == nil)
    }
}

/// Returns page 1 but cancels the calling task on the way out, like a cancellation that
/// arrives just after the response.
private struct CancelsAfterResponseAPI: RickAndMortyAPI {
    func episodes(page: Int) async throws -> EpisodePage {
        withUnsafeCurrentTask { $0?.cancel() }
        return .make(ids: 1...20, hasNextPage: true)
    }

    func character(id: Int) async throws -> CharacterDetails {
        throw APIError.http(statusCode: 404)
    }

    func portrait(from url: URL) async throws -> Data {
        throw APIError.http(statusCode: 404)
    }
}
