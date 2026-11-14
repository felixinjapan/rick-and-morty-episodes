import Foundation

/// One page of the paginated `/episode` endpoint.
struct EpisodePage: Sendable, Equatable {
    let episodes: [Episode]
    let pageCount: Int
    let hasNextPage: Bool
}
