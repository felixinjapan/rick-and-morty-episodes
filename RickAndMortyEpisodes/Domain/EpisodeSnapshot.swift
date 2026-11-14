import Foundation

/// The episodes loaded so far, from page 1 on. This is what the repository saves and
/// restores; the file format itself is `CachedEpisodeSnapshot`.
struct EpisodeSnapshot: Sendable, Equatable {
    let episodes: [Episode]
    /// The page to load next, or `nil` once the whole list is loaded.
    let nextPage: Int?
    /// When page 1 was fetched; drives "Last updated" and the staleness check.
    let refreshedAt: Date

    init(episodes: [Episode], nextPage: Int? = nil, refreshedAt: Date) {
        self.episodes = episodes
        self.nextPage = nextPage
        self.refreshedAt = refreshedAt
    }
}
