#if DEBUG
import Foundation

struct UnavailableRickAndMortyAPI: RickAndMortyAPI {
    func episodes(page: Int) async throws -> EpisodePage { throw APIError.offline }
    func character(id: Int) async throws -> CharacterDetails { throw APIError.offline }
    func portrait(from url: URL) async throws -> Data { throw APIError.offline }
}
#endif
