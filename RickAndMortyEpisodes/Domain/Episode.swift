import Foundation

/// An episode as the app uses it. Decoupled from the API's JSON shape (see `EpisodeDTO`)
/// so the persisted cache and the UI don't break when the API adds or renames fields.
struct Episode: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    /// Raw API value, e.g. "December 2, 2013". Kept raw so the display format can change
    /// without migrating the cache.
    let airDate: String
    /// Episode code, e.g. "S01E01".
    let code: String
    let characterIDs: [Int]
}

/// One page of the paginated `/episode` endpoint.
struct EpisodePage: Sendable, Equatable {
    let episodes: [Episode]
    let pageCount: Int
    let hasNextPage: Bool
}

/// The episodes loaded so far, from page 1 on, as they are cached on disk.
/// `nextPage` is the page to load next, or `nil` once the whole list is loaded.
struct EpisodeSnapshot: Codable, Sendable, Equatable {
    let episodes: [Episode]
    /// Optional, so caches written before this field existed load as complete lists.
    let nextPage: Int?
    /// When page 1 was fetched; drives "Last updated" and the staleness check.
    let refreshedAt: Date

    init(episodes: [Episode], nextPage: Int? = nil, refreshedAt: Date) {
        self.episodes = episodes
        self.nextPage = nextPage
        self.refreshedAt = refreshedAt
    }
}
