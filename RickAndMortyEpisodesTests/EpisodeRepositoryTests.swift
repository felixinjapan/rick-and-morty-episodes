import Foundation
import Testing
@testable import RickAndMortyEpisodes

private let apiToDomainErrors: [(APIError, EpisodeError)] = [
    (.offline, .offline),
    (.timedOut, .timedOut),
    (.http(statusCode: 404), .notFound),
    (.http(statusCode: 429), .rateLimited),
    (.http(statusCode: 503), .serverUnavailable),
    (.invalidResponse, .serverUnavailable),
    (.decoding, .unreadableData),
    (.http(statusCode: 400), .failed),
    (.transport(.cannotFindHost), .failed),
]

@Suite("Episode repository")
struct EpisodeRepositoryTests {
    @Test("Refresh fetches only the first page and saves it as the start of the list")
    func refreshFetchesFirstPage() async throws {
        let api = threePageAPI()
        let previous = EpisodeSnapshot(episodes: (1...45).map(Episode.make), refreshedAt: fixedDate)
        let store = try await FileEpisodeStore.temporary(containing: previous)
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate.addingTimeInterval(60) })

        let snapshot = try await repository.refreshFirstPage()

        #expect(await api.requestedPages == [1])
        #expect(snapshot.episodes.map(\.id) == Array(1...20))
        #expect(snapshot.nextPage == 2)
        #expect(snapshot.refreshedAt == fixedDate.addingTimeInterval(60))
        #expect(try await store.load() == snapshot)
    }

    @Test("Network errors reach callers as domain errors", arguments: apiToDomainErrors)
    func errorTranslation(apiError: APIError, expected: EpisodeError) async {
        let repository = DefaultEpisodeRepository(api: StubAPI(characters: [1: .failure(apiError)]), store: .temporary())
        await #expect(throws: expected) {
            try await repository.character(id: 1)
        }
    }

    @Test("Loading pages appends each one and saves the list so far")
    func loadPagesSavesEach() async throws {
        let store = FileEpisodeStore.temporary()
        let repository = DefaultEpisodeRepository(api: threePageAPI(), store: store, now: { fixedDate })

        let first = try await repository.loadNextPage(after: nil)
        #expect(first == EpisodeSnapshot(episodes: (1...20).map(Episode.make), nextPage: 2, refreshedAt: fixedDate))
        #expect(try await store.load() == first)

        let second = try await repository.loadNextPage(after: first)
        #expect(second.episodes.map(\.id) == Array(1...40))
        #expect(second.nextPage == 3)
        #expect(second.refreshedAt == fixedDate)
        #expect(try await store.load() == second)
    }

    @Test("A page that arrives after a refresh doesn't overwrite the refreshed list")
    func latePageAfterRefresh() async throws {
        let api = threePageAPI()
        let store = FileEpisodeStore.temporary()
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate })
        let first = try await repository.loadNextPage(after: nil)

        let gate = Gate()
        await api.holdPage(2, until: gate)
        let lateLoad = Task { try await repository.loadNextPage(after: first) }
        while !(await api.requestedPages.contains(2)) { await Task.yield() }
        await api.setPage(1, .success(.make(ids: 101...120, pageCount: 3, hasNextPage: true)))
        let refreshed = try await repository.refreshFirstPage()
        await gate.open()

        #expect(try await lateLoad.value == refreshed)
        #expect(try await store.load() == refreshed)
    }

    @Test("A failed refresh leaves the previous cache untouched")
    func failedRefreshKeepsCache() async throws {
        let api = threePageAPI()
        await api.setPage(1, .failure(APIError.http(statusCode: 500)))
        let previous = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        let store = try await FileEpisodeStore.temporary(containing: previous)
        let repository = DefaultEpisodeRepository(api: api, store: store)

        await #expect(throws: EpisodeError.serverUnavailable) {
            try await repository.refreshFirstPage()
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

        let refresh = Task { try await repository.refreshFirstPage() }
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
        #expect(await repository.currentSnapshot() == nil)
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
