#if DEBUG
import Foundation
import os

/// A long catalogue with 12 episodes per page, one second of latency, and one recoverable error.
actor DelayedEpisodeFeed: RickAndMortyAPI {
    private let recorded = LiveRickAndMortyAPI.recorded()
    private let logger = Logger(category: "DelayedEpisodeFeed")
    private let endlessCharacters: Bool
    private var failedPageFour = false

    init(endlessCharacters: Bool = false) {
        self.endlessCharacters = endlessCharacters
    }

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
            let characterIDs = endlessCharacters && id == 1 ? Array(1...10_000) : [1, 2]
            return Episode(id: id, name: "Episode \(id)", airDate: nil, code: "E\(id)", characterIDs: characterIDs)
        }
        return EpisodePage(episodes: episodes, hasNextPage: page * pageSize < totalCount, totalCount: totalCount)
    }

    func character(id: Int) async throws -> CharacterDetails {
        if endlessCharacters { return makeCharacter(id) }
        return try await recorded.character(id: id)
    }
    func characters(ids: [Int]) async throws -> [CharacterDetails] {
        try await Task.sleep(for: endlessCharacters ? .seconds(1) : .seconds(3))
        if endlessCharacters { return ids.map(makeCharacter) }
        return try await recorded.characters(ids: ids)
    }
    func portrait(from url: URL) async throws -> Data { try await recorded.portrait(from: url) }

    private func makeCharacter(_ id: Int) -> CharacterDetails {
        CharacterDetails(
            id: id, name: "Endless Character \(id)", status: .unknown,
            species: "", originName: "", episodeCount: 0, imageURL: nil
        )
    }
}
#endif
