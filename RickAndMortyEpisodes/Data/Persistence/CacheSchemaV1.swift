import Foundation
import SwiftData

/// Storage models stay inside the persistence layer; repositories exchange Sendable domain values.
enum CacheSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [EpisodeRecord.self, SnapshotRecord.self, CharacterRecord.self] }

    @Model
    final class EpisodeRecord {
        @Attribute(.unique) var id: Int
        var position: Int
        var name: String
        var airDate: Date?
        var code: String
        var characterIDs: [Int]

        init(_ episode: Episode, position: Int) {
            id = episode.id
            self.position = position
            name = episode.name
            airDate = episode.airDate
            code = episode.code
            characterIDs = episode.characterIDs
        }

        func update(_ episode: Episode, position: Int) {
            self.position = position
            name = episode.name
            airDate = episode.airDate
            code = episode.code
            characterIDs = episode.characterIDs
        }

        func toDomain() -> Episode {
            Episode(id: id, name: name, airDate: airDate, code: code, characterIDs: characterIDs)
        }
    }

    @Model
    final class SnapshotRecord {
        @Attribute(.unique) var key: String
        var nextPage: Int?
        var totalCount: Int
        var refreshedAt: Date

        init(_ snapshot: EpisodeSnapshot) {
            key = "episodes"
            nextPage = snapshot.nextPage
            totalCount = snapshot.totalCount
            refreshedAt = snapshot.refreshedAt
        }

        func update(_ snapshot: EpisodeSnapshot) {
            nextPage = snapshot.nextPage
            totalCount = snapshot.totalCount
            refreshedAt = snapshot.refreshedAt
        }
    }

    @Model
    final class CharacterRecord {
        @Attribute(.unique) var id: Int
        var name: String
        var status: String
        var species: String
        var originName: String
        var episodeCount: Int
        var imageURL: URL?
        var catalogueCount: Int?
        var savedAt: Date

        init(_ stored: StoredCharacter) {
            let details = stored.details
            id = details.id
            name = details.name
            status = Self.statusValue(details.status)
            species = details.species
            originName = details.originName
            episodeCount = details.episodeCount
            imageURL = details.imageURL
            catalogueCount = stored.catalogueCount
            savedAt = stored.savedAt
        }

        func update(_ stored: StoredCharacter) {
            let details = stored.details
            name = details.name
            status = Self.statusValue(details.status)
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
                    id: id, name: name, status: CharacterStatus(apiValue: status), species: species,
                    originName: originName, episodeCount: episodeCount, imageURL: imageURL
                ),
                catalogueCount: catalogueCount,
                savedAt: savedAt
            )
        }

        private static func statusValue(_ status: CharacterStatus) -> String {
            switch status {
            case .alive: "alive"
            case .dead: "dead"
            case .unknown: "unknown"
            }
        }
    }
}

enum CacheMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CacheSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
