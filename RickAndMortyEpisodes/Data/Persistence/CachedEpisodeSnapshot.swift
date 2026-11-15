import Foundation

/// The cache file's format, separate from the domain types so changing them can't change what is
/// on disk. Bump `currentVersion` when it changes; another version counts as no cache.
struct CachedEpisodeSnapshot: Codable {
    static let currentVersion = 2

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
    let totalCount: Int
    let refreshedAt: Date
}

extension CachedEpisodeSnapshot {
    init(_ snapshot: EpisodeSnapshot) {
        version = Self.currentVersion
        episodes = snapshot.episodes.map {
            CachedEpisode(id: $0.id, name: $0.name, airDate: $0.airDate, code: $0.code, characterIDs: $0.characterIDs)
        }
        nextPage = snapshot.nextPage
        totalCount = snapshot.totalCount
        refreshedAt = snapshot.refreshedAt
    }

    func toDomain() -> EpisodeSnapshot {
        EpisodeSnapshot(
            episodes: episodes.map {
                Episode(id: $0.id, name: $0.name, airDate: $0.airDate, code: $0.code, characterIDs: $0.characterIDs)
            },
            nextPage: nextPage,
            totalCount: totalCount,
            refreshedAt: refreshedAt
        )
    }
}
