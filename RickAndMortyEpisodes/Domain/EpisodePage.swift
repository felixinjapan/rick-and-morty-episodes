import Foundation

struct EpisodePage: Sendable, Equatable {
    let episodes: [Episode]
    let hasNextPage: Bool
    /// How many episodes exist in all, across every page.
    let totalCount: Int
}
