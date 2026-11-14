import Foundation

/// An episode as the API sends it (https://rickandmortyapi.com/documentation).
/// Only the fields the app uses are decoded, so unrelated API additions can't break decoding.
/// `airDate` stays a string here and is parsed in `toDomain()`, so one unreadable date
/// affects only that episode instead of failing the whole page.
struct EpisodeDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let airDate: String
    let episode: String
    let characters: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, episode, characters
        case airDate = "air_date"
    }
}

// MARK: - Mapping to the domain

extension EpisodeDTO {
    func toDomain() -> Episode {
        Episode(
            id: id,
            name: name,
            airDate: AirDateParser.date(from: airDate),
            code: episode,
            characterIDs: characters.compactMap(ResourceID.from)
        )
    }
}
