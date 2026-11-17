import Foundation

struct EpisodePageDTO: Decodable, Sendable {
    struct Info: Decodable, Sendable {
        /// How many episodes exist in all, across every page.
        let count: Int
        let next: String?
    }

    let info: Info
    let results: [EpisodeDTO]
}

extension EpisodePageDTO {
    func toDomain() -> EpisodePage {
        EpisodePage(
            episodes: results.map { $0.toDomain() },
            hasNextPage: info.next != nil,
            totalCount: info.count
        )
    }
}
