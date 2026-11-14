#if DEBUG
import Foundation

/// The real API client running on recorded data.
struct RecordedRickAndMortyAPI: RickAndMortyAPI {
    /// The recorded transport answers by path (`/episode`, `/character/{id}`), so the host is
    /// never contacted; `.invalid` is a reserved domain that can't resolve.
    private let client = LiveRickAndMortyAPI(baseURL: URL(string: "https://recorded.invalid/api")!, transport: .recorded)

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
#endif
