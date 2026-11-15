import Foundation
import os
import Testing
@testable import RickAndMortyEpisodes

private let apiToDomainErrors: [(APIError, DataError)] = [
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
    func errorTranslation(apiError: APIError, expected: DataError) async {
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

        // A new repository over the same folder, like a relaunch.
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
        let size = OSAllocatedUnfairLock<Int?>(initialState: 45)
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, catalogueCount: { size.withLock { $0 } })
        _ = try await repository.character(id: 1)

        size.withLock { $0 = 46 }
        await api.setCharacter(1, .failure(apiError))

        #expect(try await repository.character(id: 1) == .rick)
    }

    @Test("A character the server says no longer exists is not served from old details")
    func notFoundIsNotServedFromOldDetails() async throws {
        let size = OSAllocatedUnfairLock<Int?>(initialState: 45)
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, catalogueCount: { size.withLock { $0 } })
        _ = try await repository.character(id: 1)

        size.withLock { $0 = 46 }
        await api.setCharacter(1, .failure(APIError.http(statusCode: 404)))

        await #expect(throws: DataError.notFound) { try await repository.character(id: 1) }
    }

    @Test("A cancelled request is not answered with old details")
    func cancellationIsNotServedFromOldDetails() async throws {
        let size = OSAllocatedUnfairLock<Int?>(initialState: 45)
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, catalogueCount: { size.withLock { $0 } })
        _ = try await repository.character(id: 1)

        size.withLock { $0 = 46 }
        await api.setCharacter(1, .failure(CancellationError()))

        await #expect(throws: CancellationError.self) { try await repository.character(id: 1) }
    }

    @Test("A failed save doesn't fail the load")
    func saveFailureIsIgnored() async throws {
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, store: try .makeUnwritable())

        #expect(try await repository.character(id: 1) == .rick)
        // Still answered from memory for the rest of the session.
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
