import Foundation

/// One page of the `GET /episode` response (https://rickandmortyapi.com/documentation#episode)
/// Decodes only the fields the app uses, so new API fields can't break it.
struct EpisodePageDTO: Decodable, Sendable {
    struct Info: Decodable, Sendable {
        /// URL of the next page; `nil` on the last page.
        let next: String?
    }

    let info: Info
    let results: [EpisodeDTO]
}

// MARK: - Mapping to the domain

extension EpisodePageDTO {
    func toDomain() -> EpisodePage {
        EpisodePage(
            episodes: results.map { $0.toDomain() },
            hasNextPage: info.next != nil
        )
    }
}
