import Foundation

/// A saved character as it is stored: the details plus what is needed to judge later whether they
/// are still good. The file format, separate from the domain type so changing one can't change what
/// is on disk. Bump `currentVersion` when it changes; another version counts as no cache.
struct StoredCharacter: Sendable, Equatable {
    let details: CharacterDetails
    /// The catalogue size when the details were saved, if known. New episodes change a character's
    /// episode count, so a different size means the details may be out of date.
    let catalogueCount: Int?
    let savedAt: Date
}

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
        status = switch details.status {
        case .alive: "alive"
        case .dead: "dead"
        case .unknown: "unknown"
        }
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
