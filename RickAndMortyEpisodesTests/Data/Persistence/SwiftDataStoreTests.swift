import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("SwiftData cache")
struct SwiftDataStoreTests {
    private let saved = StoredCharacter(details: .rick, catalogueCount: 51, savedAt: fixedDate)

    @Test("An empty database has no snapshot or characters")
    func empty() async throws {
        let store = SwiftDataStore.makeInMemory()
        #expect(try await store.load() == nil)
        #expect(try await store.load(id: 1) == nil)
    }

    @Test("Episodes preserve their order, optional dates, character IDs and pagination metadata")
    func snapshotRoundTrip() async throws {
        let store = SwiftDataStore.makeInMemory()
        let snapshot = EpisodeSnapshot(
            episodes: [
                .make(id: 20),
                Episode(id: 3, name: "Unknown date", airDate: nil, code: "S01E03", characterIDs: [7, 2, 9]),
                .make(id: 1),
            ],
            nextPage: 2, totalCount: 51, refreshedAt: fixedDate
        )
        try await store.save(snapshot)
        #expect(try await store.load() == snapshot)
    }

    @Test("Replacing a snapshot updates existing episodes and removes obsolete rows")
    func replaceSnapshot() async throws {
        let store = SwiftDataStore.makeInMemory()
        try await store.save(EpisodeSnapshot(
            episodes: (1...45).map(Episode.make), nextPage: 4, totalCount: 51, refreshedAt: fixedDate
        ))
        let replacement = EpisodeSnapshot(
            episodes: [Episode(id: 1, name: "Revised pilot", airDate: nil, code: "S01E01", characterIDs: [])],
            refreshedAt: fixedDate.addingTimeInterval(60)
        )
        try await store.save(replacement)
        try await store.save(replacement)
        #expect(try await store.load() == replacement)

        let empty = EpisodeSnapshot(episodes: [], refreshedAt: fixedDate.addingTimeInterval(120))
        try await store.save(empty)
        #expect(try await store.load() == empty)
    }

    @Test("A saved character reads back unchanged")
    func characterRoundTrip() async throws {
        let store = SwiftDataStore.makeInMemory()
        try await store.save(saved)
        #expect(try await store.load(id: 1) == saved)
    }

    @Test("Every status and absent metadata survive saving", arguments: [CharacterStatus.alive, .dead, .unknown])
    func statusRoundTrip(status: CharacterStatus) async throws {
        let store = SwiftDataStore.makeInMemory()
        let details = CharacterDetails(
            id: 7, name: "X", status: status, species: "Alien", originName: "Y", episodeCount: 2, imageURL: nil
        )
        let stored = StoredCharacter(details: details, catalogueCount: nil, savedAt: fixedDate)
        try await store.save(stored)
        #expect(try await store.load(id: 7) == stored)
    }

    @Test("Updating a character replaces all its fields and leaves other characters alone")
    func updateCharacter() async throws {
        let store = SwiftDataStore.makeInMemory()
        let other = StoredCharacter(
            details: CharacterDetails(
                id: 2, name: "Morty", status: .alive, species: "Human", originName: "Earth", episodeCount: 51, imageURL: nil
            ),
            catalogueCount: 51, savedAt: fixedDate
        )
        let replacement = StoredCharacter(
            details: CharacterDetails(
                id: 1, name: "Updated Rick", status: .dead, species: "Alien", originName: "Unknown",
                episodeCount: 52, imageURL: nil
            ),
            catalogueCount: nil, savedAt: fixedDate.addingTimeInterval(60)
        )
        try await store.save(saved)
        try await store.save(other)
        try await store.save(replacement)
        #expect(try await store.load(id: 1) == replacement)
        #expect(try await store.load(id: 2) == other)
    }

    @Test("Episodes and characters survive reopening an on-disk database in a path with spaces")
    func reopenDatabase() async throws {
        let directory = URL.temporaryDirectory.appending(path: "Application Support \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: SwiftDataStore.defaultFileName)
        let snapshot = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], nextPage: 2, totalCount: 51, refreshedAt: fixedDate)
        let first = SwiftDataStore(storeURL: url)
        try await first.save(snapshot)
        try await first.save(saved)

        let reopened = SwiftDataStore(storeURL: url)
        #expect(try await reopened.load() == snapshot)
        #expect(try await reopened.load(id: 1) == saved)
        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test("Concurrent episode and character writes share one database without losing either")
    func concurrentWrites() async throws {
        let store = SwiftDataStore.makeInMemory()
        let snapshot = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        async let episodes: Void = store.save(snapshot)
        async let character: Void = store.save(saved)
        _ = try await (episodes, character)
        #expect(try await store.load() == snapshot)
        #expect(try await store.load(id: 1) == saved)
    }

    @Test("Unavailable databases report errors to the repository")
    func unavailableDatabase() async throws {
        let store = try SwiftDataStore.makeUnwritable()
        await #expect(throws: (any Error).self) { try await store.load() }
        await #expect(throws: (any Error).self) { try await store.save(saved) }
    }

    @Test("A corrupt database can be replaced by newly fetched data")
    func corruptDatabaseIsRebuilt() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: SwiftDataStore.defaultFileName)
        try Data("damaged database".utf8).write(to: url)
        let unrelated = directory.appending(path: "portrait.png")
        let portrait = Data("unrelated image".utf8)
        try portrait.write(to: unrelated)
        let store = SwiftDataStore(storeURL: url)
        // Reading the broken cache may fail, but a successful fetch must restore offline storage.
        _ = try? await store.load()
        let snapshot = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        try await store.save(snapshot)
        try await store.save(saved)

        let reopened = SwiftDataStore(storeURL: url)
        #expect(try await reopened.load() == snapshot)
        #expect(try await reopened.load(id: 1) == saved)
        #expect(try Data(contentsOf: unrelated) == portrait)
    }

    @Test("Existing cache directories are excluded from backups too")
    func existingDirectoryIsExcludedFromBackup() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = SwiftDataStore(storeURL: directory.appending(path: SwiftDataStore.defaultFileName))
        try await store.save(saved)
        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test("Duplicate episode IDs reject the whole snapshot and preserve the previous cache")
    func duplicateEpisodeIDsDoNotReplaceCache() async throws {
        let store = SwiftDataStore.makeInMemory()
        let original = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], nextPage: 2, totalCount: 51, refreshedAt: fixedDate)
        try await store.save(original)
        try await store.save(saved)
        let invalid = EpisodeSnapshot(
            episodes: [.make(id: 3), .make(id: 1), .make(id: 1)],
            totalCount: 3, refreshedAt: fixedDate.addingTimeInterval(60)
        )
        await #expect(throws: CacheStoreError.duplicateEpisodeID(1)) { try await store.save(invalid) }
        #expect(try await store.load() == original)
        #expect(try await store.load(id: 1) == saved)

        let valid = EpisodeSnapshot(episodes: [.make(id: 3)], refreshedAt: fixedDate.addingTimeInterval(120))
        try await store.save(valid)
        #expect(try await store.load() == valid)
    }
}
