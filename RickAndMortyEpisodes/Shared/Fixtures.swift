#if DEBUG
import Foundation

/// Deterministic local data for SwiftUI previews and UI tests (`-uiTesting` launch argument).
/// 25 episodes over two pages, so paging and the end-of-list text are exercised.
struct FixtureRickAndMortyAPI: RickAndMortyAPI {
    static let pageSize = 20
    static let episodeCount = 25

    func episodes(page: Int) async throws -> EpisodePage {
        let pageCount = Int((Double(Self.episodeCount) / Double(Self.pageSize)).rounded(.up))
        let first = (page - 1) * Self.pageSize + 1
        let last = min(page * Self.pageSize, Self.episodeCount)
        guard first <= last else { throw APIError.http(statusCode: 404) }

        let episodes = (first...last).map { id in
            Episode(
                id: id,
                name: id == 1 ? "Pilot" : "Episode \(id)",
                airDate: "December 2, 2013",
                code: String(format: "S01E%02d", id),
                characterIDs: [1, 2, id + 2]
            )
        }
        return EpisodePage(episodes: episodes, pageCount: pageCount, hasNextPage: page < pageCount)
    }

    func character(id: Int) async throws -> CharacterDetails {
        CharacterDetails(
            id: id,
            name: id == 1 ? "Rick Sanchez" : "Character \(id)",
            status: "Alive",
            species: "Human",
            originName: "Earth (C-137)",
            episodeCount: 51,
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
