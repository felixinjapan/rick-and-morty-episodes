import Foundation

/// One page of episodes and whether another page follows. The data source returns it, and
/// the repository appends it to the `EpisodeSnapshot` it keeps.
struct EpisodePage: Sendable, Equatable {
    let episodes: [Episode]
    let hasNextPage: Bool
    /// How many episodes exist in all, across every page.
    let totalCount: Int
}
