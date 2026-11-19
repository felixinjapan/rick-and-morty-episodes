#if DEBUG
import Foundation

/// A catalogue with no episodes, for the empty state.
struct EmptyRickAndMortyAPI: RickAndMortyAPI {
    func episodes(page: Int) async throws -> EpisodePage {
        EpisodePage(episodes: [], hasNextPage: false, totalCount: 0)
    }
    func character(id: Int) async throws -> CharacterDetails { throw APIError.http(statusCode: 404) }
    func characters(ids: [Int]) async throws -> [CharacterDetails] { [] }
    func portrait(from url: URL) async throws -> Data { throw APIError.http(statusCode: 404) }
}
#endif
