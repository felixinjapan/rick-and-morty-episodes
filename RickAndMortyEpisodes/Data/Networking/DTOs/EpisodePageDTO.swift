import Foundation

/// One page of `GET /episode` as the API sends it (https://rickandmortyapi.com/documentation).
/// Only the fields the app uses are decoded, so unrelated API additions can't break decoding.
struct EpisodePageDTO: Decodable, Sendable {
    struct Info: Decodable, Sendable {
        let count: Int
        let pages: Int
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
            pageCount: info.pages,
            hasNextPage: info.next != nil
        )
    }
}
