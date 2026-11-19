import Foundation

struct EpisodeSnapshot: Sendable, Equatable {
    let episodes: [Episode]
    let nextPage: Int?
    /// How many episodes exist in all, as the API last reported. A refresh compares it with the new
    /// value to tell whether the catalogue grew.
    let totalCount: Int
    let refreshedAt: Date

    init(episodes: [Episode], nextPage: Int? = nil, totalCount: Int? = nil, refreshedAt: Date) {
        self.episodes = episodes
        self.nextPage = nextPage
        self.totalCount = totalCount ?? episodes.count
        self.refreshedAt = refreshedAt
    }
}

extension EpisodeSnapshot {
    /// The list after a fresh page 1 arrives. Episodes are only ever added at the end and page 1
    /// reports the total, so the total tells whether the cached pages after page 1 are still valid:
    /// - Same total: they all stay.
    /// - Larger total: whole cached pages stay; the last one is dropped if it was partly filled,
    ///   because new episodes land on it. `nextPage` points at the first page to load again.
    /// - Smaller total, or nothing cached: only the new page 1.
    static func refreshed(_ previous: EpisodeSnapshot?, with firstPage: EpisodePage, at date: Date) -> EpisodeSnapshot {
        let pageSize = firstPage.episodes.count
        var episodes = firstPage.episodes
        if let previous, pageSize > 0, previous.totalCount <= firstPage.totalCount {
            let unchanged = previous.totalCount == firstPage.totalCount
            let kept = unchanged ? previous.episodes.count : previous.episodes.count / pageSize * pageSize
            episodes += previous.episodes.prefix(kept).dropFirst(pageSize)
        }
        let isComplete = pageSize == 0 || !firstPage.hasNextPage || episodes.count >= firstPage.totalCount
        return EpisodeSnapshot(
            episodes: episodes,
            nextPage: isComplete ? nil : episodes.count / pageSize + 1,
            totalCount: firstPage.totalCount,
            refreshedAt: date
        )
    }
}
