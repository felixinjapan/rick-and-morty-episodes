#if DEBUG
import Foundation

/// Real responses recorded from rickandmortyapi.com (all 51 episodes and the 826 characters
/// they reference), stored in `RecordedResponses/`. Used by UI tests, previews and the
/// `-offline` launch argument so the app can run without the network.
///
/// The folder is listed in `DEVELOPMENT_ASSET_PATHS`, so it is left out of archived builds.
enum RecordedResponses {
    static func data(named name: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    /// One character from the recorded batch response, as `/character/{id}` would return it.
    static func character(id: Int) throws -> Data? {
        let all = try JSONSerialization.jsonObject(with: data(named: "characters")) as? [[String: Any]]
        guard let match = all?.first(where: { $0["id"] as? Int == id }) else { return nil }
        return try JSONSerialization.data(withJSONObject: match)
    }
}

extension HTTPTransport {
    /// Answers requests from the recorded responses, like the real server would:
    /// `/episode?page=N` and `/character/{id}`, and 404 for anything that wasn't recorded.
    static let recorded = HTTPTransport { request in
        guard let url = request.url else { throw URLError(.badURL) }
        let path = url.pathComponents
        let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "page" }?.value

        var body: Data?
        if path.last == "episode", let page {
            body = try? RecordedResponses.data(named: "episodes-page-\(page)")
        } else if path.dropLast().last == "character", let id = Int(path.last ?? "") {
            body = try RecordedResponses.character(id: id)
        }

        let response = HTTPURLResponse(url: url, statusCode: body == nil ? 404 : 200, httpVersion: nil, headerFields: nil)!
        return (body ?? Data(#"{"error":"Not found"}"#.utf8), response)
    }
}

/// The real API client running on recorded data.
struct RecordedRickAndMortyAPI: RickAndMortyAPI {
    private let client = LiveRickAndMortyAPI(transport: .recorded)

    func episodes(page: Int) async throws -> EpisodePage {
        try await client.episodes(page: page)
    }

    func character(id: Int) async throws -> CharacterDetails {
        let character = try await client.character(id: id)
        // Avatars are served by the API's server; leave them out so offline mode makes no requests.
        return CharacterDetails(
            id: character.id,
            name: character.name,
            status: character.status,
            species: character.species,
            originName: character.originName,
            episodeCount: character.episodeCount,
            imageURL: nil
        )
    }
}

actor InMemoryEpisodeStore: EpisodeStore {
    private var snapshot: EpisodeSnapshot?

    init(snapshot: EpisodeSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() -> EpisodeSnapshot? { snapshot }
    func save(_ snapshot: EpisodeSnapshot) { self.snapshot = snapshot }
}
#endif
