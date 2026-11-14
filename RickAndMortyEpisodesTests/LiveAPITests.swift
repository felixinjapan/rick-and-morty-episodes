import Foundation
import Testing
@testable import RickAndMortyEpisodes

/// Tests decoding against real recorded API responses and HTTP error mapping,
/// using closure transports instead of the network.
@Suite("Live API client")
struct LiveAPITests {
    private func api(
        status: Int = 200,
        body: Data = Data(),
        onRequest: @escaping @Sendable (URLRequest) -> Void = { _ in }
    ) -> LiveRickAndMortyAPI {
        LiveRickAndMortyAPI(baseURL: AppConfiguration.production.apiBaseURL, transport: HTTPTransport { request in
            onRequest(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (body, response)
        })
    }

    private func failingAPI(_ error: URLError.Code) -> LiveRickAndMortyAPI {
        LiveRickAndMortyAPI(baseURL: AppConfiguration.production.apiBaseURL, transport: HTTPTransport { _ in throw URLError(error) })
    }

    private let recorded = LiveRickAndMortyAPI(baseURL: AppConfiguration.production.apiBaseURL, transport: .recorded)

    @Test("Decodes a real episode page")
    func decodesEpisodePage() async throws {
        let page = try await recorded.episodes(page: 1)

        #expect(page.episodes.count == 20)
        #expect(page.hasNextPage)

        let pilot = try #require(page.episodes.first)
        #expect(pilot.name == "Pilot")
        #expect(pilot.code == "S01E01")
        #expect(pilot.formattedAirDate == "02/12/2013")
        #expect(pilot.characterIDs.prefix(2) == [1, 2])
    }

    @Test("The last page reports no next page")
    func lastPage() async throws {
        let page = try await recorded.episodes(page: 3)
        #expect(!page.hasNextPage)
        #expect(page.episodes.last?.id == 51)
    }

    @Test("Decodes a real character, counting episodes")
    func decodesCharacter() async throws {
        let character = try await recorded.character(id: 1)
        #expect(character.name == "Rick Sanchez")
        #expect(character.status == .alive)
        #expect(character.species == "Human")
        #expect(character.originName == "Earth (C-137)")
        #expect(character.episodeCount == 51)
        #expect(character.imageURL != nil)
    }

    @Test("Character status maps the API's values", arguments: [
        ("Alive", CharacterStatus.alive), ("Dead", .dead), ("unknown", .unknown), ("Zombie", .unknown),
    ])
    func statusMapping(apiValue: String, expected: CharacterStatus) {
        #expect(CharacterStatus(apiValue: apiValue) == expected)
    }

    @Test("Decodes a character whose origin is unknown")
    func decodesUnknownOrigin() async throws {
        let character = try await recorded.character(id: 19)
        #expect(character.originName == "unknown")
    }

    @Test("All 51 recorded episodes decode across the three pages")
    func allRecordedEpisodes() async throws {
        var episodes: [Episode] = []
        for page in 1...3 {
            episodes += try await recorded.episodes(page: page).episodes
        }
        #expect(episodes.map(\.id) == Array(1...51))
        #expect(episodes.allSatisfy { !$0.characterIDs.isEmpty })
        #expect(episodes.allSatisfy { $0.formattedAirDate.wholeMatch(of: /\d{2}\/\d{2}\/\d{4}/) != nil })
    }

    @Test("Builds the expected request URLs")
    func requestURLs() async throws {
        let recordedURLs = RecordedURLs()
        let api = api(body: try RecordedResponses.data(named: "episodes-page-1")) { recordedURLs.append($0.url) }
        _ = try await api.episodes(page: 2)
        #expect(recordedURLs.urls.first??.absoluteString == "https://rickandmortyapi.com/api/episode?page=2")
    }

    @Test("Non-2xx responses become HTTP errors", arguments: [404, 429, 500])
    func httpErrors(status: Int) async {
        await #expect(throws: APIError.http(statusCode: status)) {
            try await api(status: status).character(id: 1)
        }
    }

    @Test("Malformed JSON becomes a decoding error")
    func malformedJSON() async {
        await #expect(throws: APIError.decoding) {
            try await api(body: Data("{\"unexpected\": true}".utf8)).episodes(page: 1)
        }
    }

    @Test("Connectivity failures are classified")
    func transportErrors() async {
        await #expect(throws: APIError.offline) {
            try await failingAPI(.notConnectedToInternet).episodes(page: 1)
        }
        await #expect(throws: APIError.timedOut) {
            try await failingAPI(.timedOut).episodes(page: 1)
        }
    }

    @Test("A cancelled request surfaces as CancellationError, not as a user-facing error")
    func cancellation() async {
        await #expect(throws: CancellationError.self) {
            try await failingAPI(.cancelled).episodes(page: 1)
        }
    }
}

/// Thread-safe recorder for the transport closure, which runs off the test's actor.
private final class RecordedURLs: @unchecked Sendable {
    // @unchecked: all access goes through `lock`.
    private let lock = NSLock()
    private var storage: [URL?] = []

    func append(_ url: URL?) { lock.withLock { storage.append(url) } }
    var urls: [URL?] { lock.withLock { storage } }
}
