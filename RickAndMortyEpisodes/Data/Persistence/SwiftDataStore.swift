import Foundation
import SwiftData
import os

enum CacheStoreError: LocalizedError, Equatable {
    case duplicateEpisodeID(Int)

    var errorDescription: String? {
        switch self {
        case .duplicateEpisodeID(let id): "Episode snapshot contains duplicate ID \(id)."
        }
    }
}

/// One shared cache for episodes and opened characters. Opening is deferred until first use so
/// an unavailable database follows the repositories' normal cache-error handling.
actor SwiftDataStore {
    static let defaultFileName = "cache.store"

    private let storeURL: URL?
    private var storage: CacheStorage?
    private let logger = Logger(category: "SwiftDataStore")

    init(storeURL: URL) {
        self.storeURL = storeURL
    }

    private init() {
        storeURL = nil
    }

    static func makeDefault() -> SwiftDataStore {
        let directory = URL.applicationSupportDirectory.appending(path: "Cache", directoryHint: .isDirectory)
        return SwiftDataStore(storeURL: directory.appending(path: defaultFileName))
    }

    static func makeInMemory() -> SwiftDataStore {
        SwiftDataStore()
    }

    func load() async throws -> EpisodeSnapshot? {
        try await openStorage().loadEpisodes()
    }

    func save(_ snapshot: EpisodeSnapshot) async throws {
        // SwiftData's unique-ID upsert would silently collapse duplicate rows while leaving
        // the snapshot's pagination metadata unchanged. Reject the whole write instead.
        var ids: Set<Int> = []
        for episode in snapshot.episodes where !ids.insert(episode.id).inserted {
            throw CacheStoreError.duplicateEpisodeID(episode.id)
        }
        try await openStorage().saveEpisodes(snapshot)
    }

    func load(id: Int) async throws -> StoredCharacter? {
        try await openStorage().loadCharacter(id: id)
    }

    func save(_ character: StoredCharacter) async throws {
        try await openStorage().saveCharacter(character)
    }

    private func openStorage() throws -> CacheStorage {
        if let storage { return storage }
        let schema = Schema(versionedSchema: CacheSchemaV1.self)
        let configuration: ModelConfiguration
        if let storeURL {
            let directory = storeURL.deletingLastPathComponent()
            try CacheDirectory.prepare(directory)
            // The database and SQLite sidecars must remain writable during background refresh.
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path(percentEncoded: false)
            )
            // Metadata can be readable while an episode or character page is damaged.
            // Check once before creating a container, which may otherwise open successfully.
            if try CacheRecovery.rebuildIfCorrupt(at: storeURL) {
                logger.error("Rebuilding a corrupt cache database")
            }
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        let container = try ModelContainer(
            for: schema, migrationPlan: CacheMigrationPlan.self, configurations: [configuration]
        )
        let storage = CacheStorage(modelContainer: container)
        self.storage = storage
        return storage
    }
}

/// The context and every managed model stay on this actor, away from the main actor.
@ModelActor
private actor CacheStorage {
    private typealias EpisodeRecord = CacheSchemaV1.EpisodeRecord
    private typealias SnapshotRecord = CacheSchemaV1.SnapshotRecord
    private typealias CharacterRecord = CacheSchemaV1.CharacterRecord

    func loadEpisodes() throws -> EpisodeSnapshot? {
        guard let metadata = try snapshotRecord() else { return nil }
        let episodes = try modelContext.fetch(FetchDescriptor<EpisodeRecord>(sortBy: [SortDescriptor(\.position)]))
        return EpisodeSnapshot(
            episodes: episodes.map { $0.toDomain() }, nextPage: metadata.nextPage,
            totalCount: metadata.totalCount, refreshedAt: metadata.refreshedAt
        )
    }

    func saveEpisodes(_ snapshot: EpisodeSnapshot) throws {
        try saving {
            var existing = Dictionary(uniqueKeysWithValues:
                try modelContext.fetch(FetchDescriptor<EpisodeRecord>()).map { ($0.id, $0) }
            )
            for (position, episode) in snapshot.episodes.enumerated() {
                if let record = existing.removeValue(forKey: episode.id) {
                    record.update(episode, position: position)
                } else {
                    modelContext.insert(EpisodeRecord(episode, position: position))
                }
            }
            for obsolete in existing.values { modelContext.delete(obsolete) }
            if let metadata = try snapshotRecord() {
                metadata.update(snapshot)
            } else {
                modelContext.insert(SnapshotRecord(snapshot))
            }
        }
    }

    func loadCharacter(id: Int) throws -> StoredCharacter? {
        try characterRecord(id: id)?.toDomain()
    }

    func saveCharacter(_ stored: StoredCharacter) throws {
        try saving {
            if let record = try characterRecord(id: stored.details.id) {
                record.update(stored)
            } else {
                modelContext.insert(CharacterRecord(stored))
            }
        }
    }

    private func snapshotRecord() throws -> SnapshotRecord? {
        var descriptor = FetchDescriptor<SnapshotRecord>(predicate: #Predicate { $0.key == "episodes" })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func characterRecord(id: Int) throws -> CharacterRecord? {
        var descriptor = FetchDescriptor<CharacterRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Rows and pagination metadata commit together. A failed save discards pending edits so
    /// subsequent reads cannot accidentally serve data that was never persisted.
    private func saving(_ changes: () throws -> Void) throws {
        modelContext.autosaveEnabled = false
        do {
            try changes()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
