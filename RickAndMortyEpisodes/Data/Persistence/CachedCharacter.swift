import Foundation

struct StoredCharacter: Sendable, Equatable {
    let details: CharacterDetails
    /// The catalogue size when the details were saved, if known. New episodes change a character's
    /// episode count, so a different size means the details may be out of date.
    let catalogueCount: Int?
    let savedAt: Date
}

/// Bump `currentVersion` when changing the on-disk schema.
struct CachedCharacter: Codable {
    static let currentVersion = 1

    let version: Int
    let id: Int
    let name: String
    let status: String
    let species: String
    let originName: String
    let episodeCount: Int
    let imageURL: URL?
    let catalogueCount: Int?
    let savedAt: Date
}

extension CachedCharacter {
    init(_ stored: StoredCharacter) {
        let details = stored.details
        version = Self.currentVersion
        id = details.id
        name = details.name
        status = details.status.rawValue
        species = details.species
        originName = details.originName
        episodeCount = details.episodeCount
        imageURL = details.imageURL
        catalogueCount = stored.catalogueCount
        savedAt = stored.savedAt
    }

    func toDomain() -> StoredCharacter {
        StoredCharacter(
            details: CharacterDetails(
                id: id,
                name: name,
                status: CharacterStatus(apiValue: status),
                species: species,
                originName: originName,
                episodeCount: episodeCount,
                imageURL: imageURL
            ),
            catalogueCount: catalogueCount,
            savedAt: savedAt
        )
    }
}
