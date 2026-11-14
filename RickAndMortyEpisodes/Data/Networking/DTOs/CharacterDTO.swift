import Foundation

/// The `GET /character/{id}` response (https://rickandmortyapi.com/documentation#character)
/// Decodes only the fields the app uses, so new API fields can't break it.
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
            status: CharacterStatus(apiValue: status),
            species: species,
            originName: origin.name,
            episodeCount: episode.count,
            imageURL: URL(string: image)
        )
    }
}

extension CharacterStatus {
    /// Maps the API's status text; values the app doesn't know become `.unknown`.
    init(apiValue: String) {
        switch apiValue.lowercased() {
        case "alive": self = .alive
        case "dead": self = .dead
        default: self = .unknown
        }
    }
}
