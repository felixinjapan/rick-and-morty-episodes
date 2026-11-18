#if DEBUG
import Foundation
import os

/// A long catalogue with 12 episodes per page, one second of latency, and one recoverable error.
actor DelayedEpisodeFeed: RickAndMortyAPI {
    enum Cast: String {
        case recorded = "Delayed Episode Feed"
        case endless = "Endless Characters"
        case edgeCases = "Character Edge Cases"
    }

    private let recorded = LiveRickAndMortyAPI.recorded()
    private let logger = Logger(category: "DelayedEpisodeFeed")
    private let cast: Cast
    private var failedPageFour = false
    private var failedCharacterBatch = false

    private static let corruptPortraitID = 9_001
    private static let missingCharacterID = 9_002
    private static let unicodeCharacterID = 9_003
    private static let transientCharacterID = 9_004

    init(cast: Cast) {
        self.cast = cast
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
            Episode(id: id, name: "Episode \(id)", airDate: nil, code: "E\(id)", characterIDs: cast(for: id))
        }
        return EpisodePage(episodes: episodes, hasNextPage: page * pageSize < totalCount, totalCount: totalCount)
    }

    func character(id: Int) async throws -> CharacterDetails {
        if cast == .edgeCases && id == Self.missingCharacterID { throw APIError.http(statusCode: 404) }
        if cast != .recorded { return makeCharacter(id) }
        return try await recorded.character(id: id)
    }
    func characters(ids: [Int]) async throws -> [CharacterDetails] {
        logger.info("Requested simulated character batch of \(ids.count): \(ids.first ?? 0)...\(ids.last ?? 0)")
        try await Task.sleep(for: cast == .recorded ? .seconds(3) : .seconds(1))
        if cast == .edgeCases {
            if ids.contains(Self.transientCharacterID), !failedCharacterBatch {
                failedCharacterBatch = true
                throw APIError.http(statusCode: 503)
            }
            return ids.reversed().filter { $0 != Self.missingCharacterID }.map(makeCharacter)
        }
        if cast == .endless { return ids.map(makeCharacter) }
        return try await recorded.characters(ids: ids)
    }
    func portrait(from url: URL) async throws -> Data {
        if cast == .edgeCases, url.lastPathComponent == "corrupt.png" { return Data("not an image".utf8) }
        return try await recorded.portrait(from: url)
    }

    private func cast(for episodeID: Int) -> [Int] {
        if episodeID == 1 && cast != .recorded { return Array(1...10_000) }
        if cast == .edgeCases {
            switch episodeID {
            case 2: return []
            case 3: return [Self.missingCharacterID, Self.corruptPortraitID, Self.unicodeCharacterID, Self.unicodeCharacterID, 0, -1]
            case 4: return [Self.transientCharacterID]
            default: break
            }
        }
        return [1, 2]
    }

    private func makeCharacter(_ id: Int) -> CharacterDetails {
        if cast == .endless {
            // Every character has a portrait, so scrolling exercises the lazy image loading too.
            return CharacterDetails(
                id: id, name: "Endless Character \(id)", status: [.alive, .dead, .unknown][id % 3],
                species: id.isMultiple(of: 2) ? "Human" : "Alien", originName: "Earth (C-137)",
                episodeCount: id % 51 + 1,
                imageURL: URL(string: "https://rickandmortyapi.com/api/character/avatar/\(id).jpeg")
            )
        }
        let name = cast == .edgeCases && id == Self.unicodeCharacterID
            ? "偏遠太空站 🛸 " + String(repeating: "مرحبا بالعالم ", count: 16)
            : "Endless Character \(id)"
        let imageURL = cast == .edgeCases && id == Self.corruptPortraitID
            ? URL(string: "https://rickandmortyapi.com/api/character/avatar/corrupt.png")
            : nil
        return CharacterDetails(
            id: id, name: name, status: .unknown,
            species: "", originName: "", episodeCount: 0, imageURL: imageURL
        )
    }
}
#endif
