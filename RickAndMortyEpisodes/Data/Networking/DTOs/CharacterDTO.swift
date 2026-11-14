import Foundation

/// A character from `GET /character/{id}` as the API sends it
/// (https://rickandmortyapi.com/documentation). Only the fields the app uses are decoded,
/// so unrelated API additions can't break decoding.
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

// MARK: - Mapping to the domain

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
