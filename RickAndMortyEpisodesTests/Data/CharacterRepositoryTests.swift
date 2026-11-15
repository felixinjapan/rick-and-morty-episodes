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

    // MARK: - Portraits

    private static let avatar = URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")!

    @Test("A portrait is downloaded once and then read from disk")
    func portraitDownloadedOnce() async throws {
        let api = StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api)

        let first = try await repository.portrait(for: .rick)
        let second = try await repository.portrait(for: .rick)

        #expect(first == RecordedResponses.portrait)
        #expect(second == first)
        #expect(await api.requestedPortraits == [Self.avatar])
    }

    @Test("A portrait seen in an earlier session is read from disk, with no request")
    func portraitSavedAcrossSessions() async throws {
        let portraits = PortraitStore.makeTemporary()
        let first = DefaultCharacterRepository.makeTemporary(
            api: StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)]), portraits: portraits
        )
        _ = try await first.portrait(for: .rick)

        let api = StubAPI()
        let second = DefaultCharacterRepository.makeTemporary(api: api, portraits: portraits)

        #expect(try await second.portrait(for: .rick) == RecordedResponses.portrait)
        #expect(await api.requestedPortraits.isEmpty)
    }

    @Test("A saved portrait is kept when the catalogue changes and the network is gone")
    func portraitSurvivesCatalogueChange() async throws {
        let size = OSAllocatedUnfairLock<Int?>(initialState: 45)
        let portraits = PortraitStore.makeTemporary()
        let online = DefaultCharacterRepository.makeTemporary(
            api: StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)]),
            portraits: portraits, catalogueCount: { size.withLock { $0 } }
        )
        _ = try await online.portrait(for: .rick)

        size.withLock { $0 = 46 }
        let offline = DefaultCharacterRepository.makeTemporary(
            api: StubAPI(portraits: [Self.avatar: .failure(APIError.offline)]),
            portraits: portraits, catalogueCount: { size.withLock { $0 } }
        )

        #expect(try await offline.portrait(for: .rick) == RecordedResponses.portrait)
    }

    @Test("A portrait that was never seen fails when offline", arguments: apiToDomainErrors)
    func portraitErrorTranslation(apiError: APIError, expected: DataError) async {
        let repository = DefaultCharacterRepository.makeTemporary(
            api: StubAPI(portraits: [Self.avatar: .failure(apiError)])
        )
        await #expect(throws: expected) { try await repository.portrait(for: .rick) }
    }

    @Test("A character without an image URL has no portrait")
    func noImageURL() async {
        let withoutImage = CharacterDetails(
            id: 9, name: "X", status: .alive, species: "Alien", originName: "Y", episodeCount: 1, imageURL: nil
        )
        let repository = DefaultCharacterRepository.makeTemporary(api: StubAPI())
        await #expect(throws: DataError.notFound) { try await repository.portrait(for: withoutImage) }
    }

    @Test("A failed portrait save doesn't fail the load")
    func portraitSaveFailureIsIgnored() async throws {
        let api = StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api, portraits: try .makeUnwritable())

        #expect(try await repository.portrait(for: .rick) == RecordedResponses.portrait)
    }

    @Test("A cancelled portrait download is not answered with anything")
    func portraitCancellation() async {
        let api = StubAPI(portraits: [Self.avatar: .failure(CancellationError())])
        let repository = DefaultCharacterRepository.makeTemporary(api: api)
        await #expect(throws: CancellationError.self) { try await repository.portrait(for: .rick) }
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
