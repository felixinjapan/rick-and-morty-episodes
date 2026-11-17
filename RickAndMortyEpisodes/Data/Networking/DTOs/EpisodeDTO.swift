import Foundation

struct EpisodeDTO: Decodable, Sendable {
    let id: Int
    let name: String
    /// Kept as text and parsed in `toDomain()`, so a missing or bad date affects only this episode.
    let airDate: String?
    let episode: String
    let characters: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, episode, characters
        case airDate = "air_date"
    }
}

extension EpisodeDTO {
    func toDomain() -> Episode {
        Episode(
            id: id,
            name: name,
            airDate: airDate.flatMap(AirDateParser.date(from:)),
            code: episode,
            characterIDs: characters.compactMap(ResourceID.from)
        )
    }
}
