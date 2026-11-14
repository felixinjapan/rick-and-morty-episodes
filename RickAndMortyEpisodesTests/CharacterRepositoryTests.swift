import Foundation
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
        let repository = DefaultCharacterRepository(api: StubAPI(characters: [1: .failure(apiError)]))
        await #expect(throws: expected) {
            try await repository.character(id: 1)
        }
    }

    @Test("Character details are cached in memory")
    func characterCaching() async throws {
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository(api: api)

        _ = try await repository.character(id: 1)
        let second = try await repository.character(id: 1)

        #expect(second == .rick)
        #expect(await api.requestedCharacters == [1])
    }
}
