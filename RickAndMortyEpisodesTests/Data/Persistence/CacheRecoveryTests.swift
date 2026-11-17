import CoreData
import Foundation
import SQLite3
import Testing
@testable import RickAndMortyEpisodes

@Suite("Cache corruption recovery")
struct CacheRecoveryTests {
    @Test("Missing databases are not created by the recovery check")
    func missingDatabase() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: SwiftDataStore.defaultFileName)
        #expect(try !CacheRecovery.rebuildIfCorrupt(at: url))
        #expect(!FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
    }

    @Test("Readable and locked databases with another schema are preserved", arguments: [false, true])
    func foreignSchemaIsPreserved(locked: Bool) throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: SwiftDataStore.defaultFileName)
        var database: OpaquePointer?
        let opened = sqlite3_open(url.path(percentEncoded: false), &database)
        defer { sqlite3_close(database) }
        try #require(opened == SQLITE_OK)
        try #require(sqlite3_exec(database, "CREATE TABLE other_schema (value INTEGER); INSERT INTO other_schema VALUES (42)", nil, nil, nil) == SQLITE_OK)
        if locked { try #require(sqlite3_exec(database, "BEGIN EXCLUSIVE", nil, nil, nil) == SQLITE_OK) }
        defer { if locked { sqlite3_exec(database, "ROLLBACK", nil, nil, nil) } }

        #expect(try !CacheRecovery.rebuildIfCorrupt(at: url))
        #expect(try scalar("SELECT value FROM other_schema", in: database) == 42)
    }

    @Test("Unreadable files are preserved until access becomes available")
    func unreadableDatabaseIsPreserved() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: SwiftDataStore.defaultFileName)
        let original = Data("temporarily unreadable cache".utf8)
        try original.write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path(percentEncoded: false))
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path(percentEncoded: false)) }

        #expect(try !CacheRecovery.rebuildIfCorrupt(at: url))
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path(percentEncoded: false))
        #expect(try Data(contentsOf: url) == original)
    }

    @Test("Recovery leaves a readable database intact")
    func healthyDatabaseIsPreserved() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: SwiftDataStore.defaultFileName)
        let store = SwiftDataStore(storeURL: url)
        let original = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        try await store.save(original)

        #expect(try !CacheRecovery.rebuildIfCorrupt(at: url))
        #expect(try await SwiftDataStore(storeURL: url).load() == original)
    }

    @Test("Damaged episode pages are rebuilt even when the store metadata is readable")
    func damagedDataPage() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: SwiftDataStore.defaultFileName)
        try await seedDatabase(at: url)
        let offset = try episodePageOffset(at: url)
        let file = try FileHandle(forWritingTo: url)
        try file.seek(toOffset: offset)
        try file.write(contentsOf: Data(repeating: 0xff, count: 16))
        try file.close()

        // This is the gap a metadata-only probe misses: metadata reads succeed, data fetches fail.
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url, options: [NSReadOnlyPersistentStoreOption: true]
        )
        #expect(metadata[NSStoreUUIDKey] != nil)
        let reopened = SwiftDataStore(storeURL: url)
        #expect(try await reopened.load() == nil)
        let replacement = EpisodeSnapshot(episodes: [.make(id: 2)], refreshedAt: fixedDate.addingTimeInterval(60))
        try await reopened.save(replacement)
        #expect(try await SwiftDataStore(storeURL: url).load() == replacement)
    }

    private func seedDatabase(at url: URL) async throws {
        let store = SwiftDataStore(storeURL: url)
        try await store.save(EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate))
    }

    /// Locate one data page in this disposable fixture without damaging schema or metadata pages.
    private func episodePageOffset(at url: URL) throws -> UInt64 {
        var database: OpaquePointer?
        try #require(sqlite3_open(url.path(percentEncoded: false), &database) == SQLITE_OK)
        defer { sqlite3_close(database) }
        try #require(sqlite3_exec(database, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil) == SQLITE_OK)
        let page = try scalar("SELECT rootpage FROM sqlite_master WHERE name = 'ZEPISODERECORD'", in: database)
        let size = try scalar("PRAGMA page_size", in: database)
        try #require(page > 1 && size > 0)
        return UInt64((page - 1) * size)
    }

    private func scalar(_ sql: String, in database: OpaquePointer?) throws -> Int64 {
        var statement: OpaquePointer?
        let prepared = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        try #require(prepared == SQLITE_OK)
        try #require(sqlite3_step(statement) == SQLITE_ROW)
        return sqlite3_column_int64(statement, 0)
    }

}
