import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Episode repository")
struct EpisodeRepositoryTests {
    @Test("Refresh fetches every page, keeps API order, and saves one snapshot")
    func refreshFetchesAllPages() async throws {
        let api = threePageAPI()
        let store = RecordingStore()
        let repository = EpisodeRepository(api: api, store: store, now: { fixedDate })

        let snapshot = try await repository.refreshAll()

        #expect(snapshot.episodes.map(\.id) == Array(1...45))
        #expect(snapshot.refreshedAt == fixedDate)
        #expect(await store.snapshot == snapshot)
        #expect(await store.saveCount == 1)
        #expect(await api.requestedPages.sorted() == [1, 2, 3])
    }

    @Test("A failed page leaves the previous cache untouched")
    func failedRefreshKeepsCache() async throws {
        let api = threePageAPI()
        await api.setPage(2, .failure(APIError.http(statusCode: 500)))
        let previous = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: .distantPast)
        let store = RecordingStore(snapshot: previous)
        let repository = EpisodeRepository(api: api, store: store)

        await #expect(throws: APIError.http(statusCode: 500)) {
            try await repository.refreshAll()
        }
        #expect(await store.snapshot == previous)
        #expect(await store.saveCount == 0)
    }

    @Test("Concurrent refreshes share one set of requests")
    func concurrentRefreshesAreCoalesced() async throws {
        let api = threePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let store = RecordingStore()
        let repository = EpisodeRepository(api: api, store: store)

        async let first = repository.refreshAll()
        async let second = repository.refreshAll()

        // Wait until the first refresh is blocked on page 1, then give the second call
        // time to join it before letting the request finish.
        while await api.requestedPages.isEmpty { await Task.yield() }
        for _ in 0..<50 { await Task.yield() }
        await gate.open()

        let (a, b) = try await (first, second)
        #expect(a == b)
        #expect(await api.requestedPages.filter { $0 == 1 }.count == 1)
        #expect(await store.saveCount == 1)
    }

    @Test("A cancelled refresh saves nothing")
    func cancelledRefreshSavesNothing() async throws {
        let api = threePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let store = RecordingStore()
        let repository = EpisodeRepository(api: api, store: store)

        let refresh = Task { try await repository.refreshAll() }
        while await api.requestedPages.isEmpty { await Task.yield() }
        refresh.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await refresh.value }
        #expect(await store.saveCount == 0)
    }

    @Test("An unreadable cache is treated as no cache")
    func corruptCache() async {
        let repository = EpisodeRepository(api: StubAPI(), store: RecordingStore(failsOnLoad: true))
        #expect(await repository.cachedSnapshot() == nil)
    }

    @Test("Character details are cached in memory")
    func characterCaching() async throws {
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = EpisodeRepository(api: api, store: RecordingStore())

        _ = try await repository.character(id: 1)
        let second = try await repository.character(id: 1)

        #expect(second == .rick)
        #expect(await api.requestedCharacters == [1])
    }
}
