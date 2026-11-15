#if DEBUG
import Foundation

/// The real API client running on stub data.
struct RecordedRickAndMortyAPI: RickAndMortyAPI {
    /// The `.recorded` transport answers by path, so the host is never contacted;
    /// `.invalid` is a reserved domain that can't resolve.
    private let client = LiveRickAndMortyAPI(
        baseURL: URL(string: "https://recorded.invalid/api")!, transport: .recorded
    )

    func episodes(page: Int) async throws -> EpisodePage {
        try await client.episodes(page: page)
    }

    func character(id: Int) async throws -> CharacterDetails {
        try await client.character(id: id)
    }

    /// Avatars are served by the API's server; the transport answers with a small generated image
    /// instead, so tests and previews make no requests.
    func portrait(from url: URL) async throws -> Data {
        try await client.portrait(from: url)
    }
}
#endif
