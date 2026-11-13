import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Episode repository")
struct EpisodeRepositoryTests {
    @Test("Refresh fetches every page, keeps API order, and saves one snapshot")
    func refreshFetchesAllPages() async throws {
        let api = threePageAPI()
        let store = FileEpisodeStore.temporary()
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate })

        let snapshot = try await repository.refreshAll()

        #expect(snapshot.episodes.map(\.id) == Array(1...45))
        #expect(snapshot.refreshedAt == fixedDate)
        #expect(try await store.load() == snapshot)
        #expect(await api.requestedPages.sorted() == [1, 2, 3])
    }

    @Test("A failed page leaves the previous cache untouched")
    func failedRefreshKeepsCache() async throws {
        let api = threePageAPI()
        await api.setPage(2, .failure(APIError.http(statusCode: 500)))
        let previous = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        let store = try await FileEpisodeStore.temporary(containing: previous)
        let repository = DefaultEpisodeRepository(api: api, store: store)

        await #expect(throws: APIError.http(statusCode: 500)) {
            try await repository.refreshAll()
        }
        #expect(try await store.load() == previous)
    }

    @Test("A cancelled refresh saves nothing")
    func cancelledRefreshSavesNothing() async throws {
        let api = threePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let store = FileEpisodeStore.temporary()
        let repository = DefaultEpisodeRepository(api: api, store: store)

        let refresh = Task { try await repository.refreshAll() }
        while await api.requestedPages.isEmpty { await Task.yield() }
        refresh.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await refresh.value }
        #expect(try await store.load() == nil)
    }

    @Test("An unreadable cache is treated as no cache")
    func corruptCache() async throws {
        let fileURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        try Data("not json".utf8).write(to: fileURL)
        let repository = DefaultEpisodeRepository(api: StubAPI(), store: FileEpisodeStore(fileURL: fileURL))
        #expect(await repository.cachedSnapshot() == nil)
    }

    @Test("Character details are cached in memory")
    func characterCaching() async throws {
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultEpisodeRepository(api: api, store: .temporary())

        _ = try await repository.character(id: 1)
        let second = try await repository.character(id: 1)

        #expect(second == .rick)
        #expect(await api.requestedCharacters == [1])
    }
}
