import Foundation

// Wire formats for https://rickandmortyapi.com/documentation.
// Only the fields the app uses are decoded, so unrelated API additions can't break decoding.

struct EpisodePageDTO: Decodable, Sendable {
    struct Info: Decodable, Sendable {
        let count: Int
        let pages: Int
        let next: String?
    }

    let info: Info
    let results: [EpisodeDTO]
}

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

struct CharacterDTO: Decodable, Sendable {
    struct Origin: Decodable, Sendable {
        let name: String
    }

    let id: Int
    let name: String
    let status: String
    let species: String
    let origin: Origin
    let image: String
    let episode: [String]
}

// MARK: - Mapping to app models

extension EpisodePageDTO {
    func toDomain() -> EpisodePage {
        EpisodePage(
            episodes: results.map { $0.toDomain() },
            pageCount: info.pages,
            hasNextPage: info.next != nil
        )
    }
}

extension EpisodeDTO {
    func toDomain() -> Episode {
        Episode(
            id: id,
            name: name,
            airDate: airDate,
            code: episode,
            characterIDs: characters.compactMap(ResourceID.from)
        )
    }
}

extension CharacterDTO {
    func toDomain() -> CharacterDetails {
        CharacterDetails(
            id: id,
            name: name,
            status: status,
            species: species,
            originName: origin.name,
            episodeCount: episode.count,
            imageURL: URL(string: image)
        )
    }
}
