import Foundation
import os
import Testing
@testable import RickAndMortyEpisodes

@Suite("Live API client")
struct LiveAPITests {
    private func makeAPI(
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

    private func makeFailingAPI(_ error: URLError.Code) -> LiveRickAndMortyAPI {
        LiveRickAndMortyAPI(
            baseURL: AppConfiguration.production.apiBaseURL,
            transport: HTTPTransport { _ in throw URLError(error) }
        )
    }

    private let recorded = LiveRickAndMortyAPI(baseURL: AppConfiguration.production.apiBaseURL, transport: .recorded)

    @Test("Decodes a real episode page")
    func decodesEpisodePage() async throws {
        let page = try await recorded.episodes(page: 1)

        #expect(page.episodes.count == 20)
        #expect(page.hasNextPage)
        #expect(page.totalCount == 51)

        let pilot = try #require(page.episodes.first)
        #expect(pilot.name == "Pilot")
        #expect(pilot.code == "S01E01")
        #expect(pilot.airDate == Date(timeIntervalSince1970: 1_385_942_400))   // 2 December 2013, GMT
        #expect(pilot.characterIDs.prefix(2) == [1, 2])
    }

    @Test("The last page reports no next page")
    func lastPage() async throws {
        let page = try await recorded.episodes(page: 3)
        #expect(page.hasNextPage == false)
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

    @Test("All 51 recorded episodes decode across the three pages")
    func allRecordedEpisodes() async throws {
        var episodes: [Episode] = []
        for page in 1...3 {
            episodes += try await recorded.episodes(page: page).episodes
        }
        #expect(episodes.map(\.id) == Array(1...51))
        #expect(episodes.allSatisfy { !$0.characterIDs.isEmpty })
        #expect(episodes.allSatisfy { $0.airDate != nil })
    }

    @Test("Builds the expected request URLs")
    func requestURLs() async throws {
        let recordedURLs = OSAllocatedUnfairLock(initialState: [URL?]())
        let api = makeAPI(body: try RecordedResponses.data(named: "episodes-page-1")) { request in
            recordedURLs.withLock { $0.append(request.url) }
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        }
        _ = try await api.episodes(page: 2)
        #expect(recordedURLs.withLock { $0.first??.absoluteString } == "https://rickandmortyapi.com/api/episode?page=2")
    }

    @Test("A portrait is downloaded from the URL it is given, as an image")
    func portraitDownload() async throws {
        let recordedURLs = OSAllocatedUnfairLock(initialState: [URL?]())
        let url = try #require(URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"))
        let api = makeAPI(body: RecordedResponses.portrait) { request in
            recordedURLs.withLock { $0.append(request.url) }
            #expect(request.value(forHTTPHeaderField: "Accept") == "image/*")
        }

        let data = try await api.portrait(from: url)

        #expect(data == RecordedResponses.portrait)
        #expect(recordedURLs.withLock { $0 } == [url])
    }

    @Test("A portrait response that is not an image is rejected, so it is never saved")
    func portraitMustBeAnImage() async throws {
        let url = try #require(URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"))
        await #expect(throws: APIError.decoding) {
            try await makeAPI(body: Data("<html>Not found</html>".utf8)).portrait(from: url)
        }
    }

    @Test("A failed portrait download is an HTTP error", arguments: [404, 503])
    func portraitHTTPErrors(status: Int) async throws {
        let url = try #require(URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"))
        await #expect(throws: APIError.http(statusCode: status)) {
            try await makeAPI(status: status).portrait(from: url)
        }
    }

    @Test("Non-2xx responses become HTTP errors", arguments: [404, 429, 500])
    func httpErrors(status: Int) async {
        await #expect(throws: APIError.http(statusCode: status)) {
            try await makeAPI(status: status).character(id: 1)
        }
    }

    @Test("A missing air date affects only that episode, not the whole page")
    func nullAirDate() async throws {
        let json = """
            {"info": {"count": 1, "next": null}, "results": [
                {"id": 1, "name": "Pilot", "air_date": null, "episode": "S01E01", "characters": []}
            ]}
            """
        let page = try await makeAPI(body: Data(json.utf8)).episodes(page: 1)
        #expect(page.episodes.map(\.airDate) == [nil])
    }

    @Test("Malformed JSON becomes a decoding error")
    func malformedJSON() async {
        await #expect(throws: APIError.decoding) {
            try await makeAPI(body: Data("{\"unexpected\": true}".utf8)).episodes(page: 1)
        }
    }

    @Test("Connectivity failures are classified")
    func transportErrors() async {
        await #expect(throws: APIError.offline) {
            try await makeFailingAPI(.notConnectedToInternet).episodes(page: 1)
        }
        await #expect(throws: APIError.timedOut) {
            try await makeFailingAPI(.timedOut).episodes(page: 1)
        }
    }

    @Test("A cancelled request surfaces as CancellationError, not as a user-facing error")
    func cancellation() async {
        await #expect(throws: CancellationError.self) {
            try await makeFailingAPI(.cancelled).episodes(page: 1)
        }
    }
}
