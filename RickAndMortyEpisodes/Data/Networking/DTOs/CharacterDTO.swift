import Foundation

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

extension CharacterDTO {
    func toDomain() -> CharacterDetails {
        CharacterDetails(
            id: id,
            name: name,
            status: CharacterStatus(apiValue: status),
            species: species,
            originName: origin.name,
            episodeCount: episode.count,
            imageURL: URL(string: image)
        )
    }
}
