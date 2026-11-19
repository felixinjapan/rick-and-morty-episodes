import Foundation

struct EpisodePage: Sendable, Equatable {
    let episodes: [Episode]
    let hasNextPage: Bool
    let totalCount: Int
}
