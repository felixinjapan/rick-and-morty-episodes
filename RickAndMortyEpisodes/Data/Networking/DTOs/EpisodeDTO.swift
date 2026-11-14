import Foundation

/// One episode in the `/episode` response (https://rickandmortyapi.com/documentation#episode)
/// Decodes only the fields the app uses, so new API fields can't break it.
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

// MARK: - Mapping to the domain

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
