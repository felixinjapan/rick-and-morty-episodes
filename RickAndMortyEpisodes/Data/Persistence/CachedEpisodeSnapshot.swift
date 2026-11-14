import Foundation

/// The cache file's format. Kept separate from the domain types, so changing `Episode` or
/// `EpisodeSnapshot` can't silently change what is on disk. Bump `currentVersion` whenever
/// this format changes; a file with another version is treated as no cache.
struct CachedEpisodeSnapshot: Codable {
    static let currentVersion = 1

    struct CachedEpisode: Codable {
        let id: Int
        let name: String
        let airDate: Date?
        let code: String
        let characterIDs: [Int]
    }

    let version: Int
    let episodes: [CachedEpisode]
    let nextPage: Int?
    let refreshedAt: Date
}

extension CachedEpisodeSnapshot {
    init(_ snapshot: EpisodeSnapshot) {
        version = Self.currentVersion
        episodes = snapshot.episodes.map {
            CachedEpisode(id: $0.id, name: $0.name, airDate: $0.airDate, code: $0.code, characterIDs: $0.characterIDs)
        }
        nextPage = snapshot.nextPage
        refreshedAt = snapshot.refreshedAt
    }

    func toDomain() -> EpisodeSnapshot {
        EpisodeSnapshot(
            episodes: episodes.map {
                Episode(id: $0.id, name: $0.name, airDate: $0.airDate, code: $0.code, characterIDs: $0.characterIDs)
            },
            nextPage: nextPage,
            refreshedAt: refreshedAt
        )
    }
}
