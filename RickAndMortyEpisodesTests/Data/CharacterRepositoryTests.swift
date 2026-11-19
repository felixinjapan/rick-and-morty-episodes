import Foundation
import os
import Testing
@testable import RickAndMortyEpisodes

let apiToDomainErrors: [(APIError, RepositoryError)] = [
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

@Suite("Character repository")
struct CharacterRepositoryTests {
    @Test("Network errors reach callers as domain errors", arguments: apiToDomainErrors)
    func errorTranslation(apiError: APIError, expected: RepositoryError) async {
        let repository = DefaultCharacterRepository.makeTemporary(api: StubAPI(characters: [1: .failure(apiError)]))
        await #expect(throws: expected) {
            try await repository.character(id: 1)
        }
    }

    @Test("An opened character is saved, so opening it again makes no request")
    func secondOpenMakesNoRequest() async throws {
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api)

        _ = try await repository.character(id: 1)
        let second = try await repository.character(id: 1)

        #expect(second == .rick)
        #expect(await api.requestedCharacters == [1])
    }

    @Test("A character opened in an earlier session is read from disk, with no request")
    func savedAcrossSessions() async throws {
        let store = FileCharacterStore.makeTemporary()
        let first = DefaultCharacterRepository.makeTemporary(
            api: StubAPI(characters: [1: .success(.rick)]), store: store
        )
        _ = try await first.character(id: 1)

        let api = StubAPI()
        let second = DefaultCharacterRepository.makeTemporary(api: api, store: store)

        #expect(try await second.character(id: 1) == .rick)
        #expect(await api.requestedCharacters.isEmpty)
    }

    @Test("Characters nobody opened are not downloaded")
    func nothingIsPrefetched() async throws {
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api)

        _ = try await repository.character(id: 1)

        #expect(await api.requestedCharacters == [1])
    }

    @Test("An episode requests only uncached IDs in one batch and saves the available details")
    func episodeBatch() async throws {
        let morty = CharacterDetails(
            id: 2, name: "Morty Smith", status: .alive, species: "Human",
            originName: "Earth (C-137)", episodeCount: 1, imageURL: nil
        )
        let store = FileCharacterStore.makeTemporary()
        try await store.save(StoredCharacter(details: .rick, catalogueCount: nil, savedAt: fixedDate))
        let api = StubAPI(characters: [2: .success(morty)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, store: store)

        #expect(await repository.characters(ids: [1, 2, 2, 99999]) == [1: .rick, 2: morty])
        #expect(await api.requestedCharacterBatches == [[2, 99999]])
        #expect(await api.requestedCharacters.isEmpty)
        #expect(try await store.load(id: 2)?.details == morty)
        #expect(await repository.characters(ids: [1, 2]) == [1: .rick, 2: morty])
        #expect(await api.requestedCharacterBatches == [[2, 99999]])
    }

    @Test("A rate-limited episode batch still returns stale cached details")
    func rateLimitedEpisodeBatch() async throws {
        let store = FileCharacterStore.makeTemporary()
        try await store.save(StoredCharacter(details: .rick, catalogueCount: 45, savedAt: fixedDate))
        let api = StubAPI(characters: [1: .failure(APIError.http(statusCode: 429))])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, store: store, catalogueCount: { 46 })

        #expect(await repository.characters(ids: [1, 2]) == [1: .rick])
        #expect(await api.requestedCharacterBatches == [[1, 2]])
    }

    @Test("Details saved under another catalogue size are fetched again")
    func catalogueSizeChanged() async throws {
        let size = OSAllocatedUnfairLock<Int?>(initialState: 45)
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, catalogueCount: { size.withLock { $0 } })
        _ = try await repository.character(id: 1)

        size.withLock { $0 = 46 }
        _ = try await repository.character(id: 1)

        #expect(await api.requestedCharacters == [1, 1])
    }

    @Test("Details saved under the same catalogue size are not fetched again")
    func catalogueSizeUnchanged() async throws {
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, catalogueCount: { 45 })

        _ = try await repository.character(id: 1)
        _ = try await repository.character(id: 1)

        #expect(await api.requestedCharacters == [1])
    }

    @Test("Saved details older than the maximum age are fetched again")
    func tooOld() async throws {
        let clock = OSAllocatedUnfairLock(initialState: fixedDate)
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, maxAge: 3600, now: { clock.withLock { $0 } })
        _ = try await repository.character(id: 1)

        clock.withLock { $0 = fixedDate.addingTimeInterval(3599) }
        _ = try await repository.character(id: 1)
        #expect(await api.requestedCharacters == [1])

        clock.withLock { $0 = fixedDate.addingTimeInterval(3601) }
        _ = try await repository.character(id: 1)
        #expect(await api.requestedCharacters == [1, 1])
    }

    @Test(
        "Out of date details are still served when fetching them again fails",
        arguments: [APIError.offline, .timedOut, .http(statusCode: 503)]
    )
    func staleDetailsServedWhenFetchFails(apiError: APIError) async throws {
        let repository = try await makeRepositoryWithStaleDetails(failingWith: apiError)

        #expect(try await repository.character(id: 1) == .rick)
    }

    @Test("A character the server says no longer exists is not served from old details")
    func notFoundIsNotServedFromOldDetails() async throws {
        let repository = try await makeRepositoryWithStaleDetails(failingWith: APIError.http(statusCode: 404))

        await #expect(throws: RepositoryError.notFound) { try await repository.character(id: 1) }
    }

    @Test("A cancelled request is not answered with old details")
    func cancellationIsNotServedFromOldDetails() async throws {
        let repository = try await makeRepositoryWithStaleDetails(failingWith: CancellationError())

        await #expect(throws: CancellationError.self) { try await repository.character(id: 1) }
    }

    private func makeRepositoryWithStaleDetails(failingWith error: any Error) async throws -> DefaultCharacterRepository {
        let size = OSAllocatedUnfairLock<Int?>(initialState: 45)
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, catalogueCount: { size.withLock { $0 } })
        _ = try await repository.character(id: 1)

        size.withLock { $0 = 46 }
        await api.setCharacter(1, .failure(error))
        return repository
    }

    @Test("A failed save doesn't fail the load")
    func saveFailureIsIgnored() async throws {
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, store: try .makeUnwritable())

        #expect(try await repository.character(id: 1) == .rick)
        #expect(try await repository.character(id: 1) == .rick)
        #expect(await api.requestedCharacters == [1])
    }

    @Test("An unreadable saved file is treated as not saved")
    func corruptFile() async throws {
        let directory = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/characters")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appending(path: "1.json"))
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, store: FileCharacterStore(directory: directory))

        #expect(try await repository.character(id: 1) == .rick)
        #expect(await api.requestedCharacters == [1])
    }
}
