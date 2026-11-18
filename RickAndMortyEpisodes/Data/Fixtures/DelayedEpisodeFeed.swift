#if DEBUG
import Foundation
import os

/// A long catalogue with 12 episodes per page, one second of latency, and one recoverable error.
actor DelayedEpisodeFeed: RickAndMortyAPI {
    private let recorded = LiveRickAndMortyAPI.recorded()
    private let logger = Logger(category: "DelayedEpisodeFeed")
    private var failedPageFour = false

    func episodes(page: Int) async throws -> EpisodePage {
        logger.info("Requested simulated episode page \(page)")
        try await Task.sleep(for: .seconds(1))
        if page == 4, !failedPageFour {
            failedPageFour = true
            logger.info("Simulated page 4 failed")
            throw APIError.http(statusCode: 503)
        }

        let pageSize = 12
        let totalCount = 120_000
        let firstID = (page - 1) * pageSize + 1
        let episodes = (firstID..<(firstID + pageSize)).map { id in
            Episode(id: id, name: "Episode \(id)", airDate: nil, code: "E\(id)", characterIDs: [1, 2])
        }
        return EpisodePage(episodes: episodes, hasNextPage: page * pageSize < totalCount, totalCount: totalCount)
    }

    func character(id: Int) async throws -> CharacterDetails { try await recorded.character(id: id) }
    func characters(ids: [Int]) async throws -> [CharacterDetails] { try await recorded.characters(ids: ids) }
    func portrait(from url: URL) async throws -> Data { try await recorded.portrait(from: url) }
}
#endif
