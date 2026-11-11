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

        // Both clients must actually be registered before the shared request finishes.
        while await repository.refreshWaiterCount != 2 { await Task.yield() }
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

    @Test("Cancelling either subscriber exits promptly and preserves the other", arguments: [true, false])
    func cancellingOneRefreshWaiter(cancelFirst: Bool) async throws {
        let api = threePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let store = RecordingStore()
        let repository = EpisodeRepository(api: api, store: store)
        let first = Task { try await repository.refreshAll() }
        while await repository.refreshWaiterCount != 1 { await Task.yield() }
        let second = Task { try await repository.refreshAll() }
        while await repository.refreshWaiterCount != 2 { await Task.yield() }

        let cancelled = cancelFirst ? first : second
        let remaining = cancelFirst ? second : first
        cancelled.cancel()
        // Must complete while the request is still blocked.
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(await repository.refreshWaiterCount == 1)
        #expect(await store.saveCount == 0)

        await gate.open()
        #expect(try await remaining.value.episodes.count == 45)
        #expect(await api.requestedPages.sorted() == [1, 2, 3])
        #expect(await store.saveCount == 1)
    }

    @Test("Cancelling all subscribers cancels work and permits a new refresh")
    func cancellingAllRefreshWaiters() async throws {
        let api = threePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let store = RecordingStore()
        let repository = EpisodeRepository(api: api, store: store)
        let first = Task { try await repository.refreshAll() }
        let second = Task { try await repository.refreshAll() }
        while await repository.refreshWaiterCount != 2 { await Task.yield() }
        first.cancel()
        second.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        await #expect(throws: CancellationError.self) { try await second.value }
        #expect(await repository.refreshWaiterCount == 0)

        let retry = Task { try await repository.refreshAll() }
        while await repository.refreshWaiterCount != 1 { await Task.yield() }
        await gate.open()
        #expect(try await retry.value.episodes.count == 45)
        #expect(await store.saveCount == 1)
    }

    @Test("An already-cancelled caller never starts a refresh")
    func alreadyCancelledRefresh() async {
        let api = threePageAPI()
        let repository = EpisodeRepository(api: api, store: RecordingStore())
        let gate = Gate()
        let caller = Task {
            await gate.wait()
            return try await repository.refreshAll()
        }
        caller.cancel()
        await gate.open()
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(await api.requestedPages.isEmpty)
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
