import Foundation

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
