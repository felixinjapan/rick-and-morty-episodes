import Foundation

/// One page of `GET /episode` as the API sends it (https://rickandmortyapi.com/documentation).
/// Only the fields the app uses are decoded, so unrelated API additions can't break decoding.
struct EpisodePageDTO: Decodable, Sendable {
    struct Info: Decodable, Sendable {
        /// The next page's URL, or `nil` on the last page.
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
