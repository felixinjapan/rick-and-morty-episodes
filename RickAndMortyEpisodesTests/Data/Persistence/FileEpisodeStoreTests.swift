import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("File episode store")
struct FileEpisodeStoreTests {
    private func makeStore() -> (FileEpisodeStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return (FileEpisodeStore(fileURL: directory.appending(path: "cache.json")), directory)
    }

    @Test("A cache file from another format version is treated as no cache", arguments: [
        // The format before versioning: the air date was text.
        #"{"episodes":[{"id":1,"name":"Pilot","airDate":"December 2, 2013","code":"S01E01","characterIDs":[1]}],"refreshedAt":0}"#,
        // A future version.
        #"{"version":99,"episodes":[],"refreshedAt":0}"#,
    ])
    func otherFormatVersion(json: String) async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appending(path: "cache.json"))

        #expect(try await store.load() == nil)
    }

    @Test("Works in folders whose names contain spaces, like Application Support")
    func pathWithSpaces() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Application Support \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileEpisodeStore(fileURL: directory.appending(path: "cache.json"))
        let snapshot = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)

        try await store.save(snapshot)

        #expect(try await store.load() == snapshot)
    }
}
