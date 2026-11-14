#if DEBUG
import Foundation

/// An API with no connection: every request fails as if the device were offline.
/// UI tests use it (`-networkUnavailable`) to prove that content came from the cache.
struct UnavailableRickAndMortyAPI: RickAndMortyAPI {
    func episodes(page: Int) async throws -> EpisodePage { throw APIError.offline }
    func character(id: Int) async throws -> CharacterDetails { throw APIError.offline }
}
#endif
