import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("File episode store")
struct FileEpisodeStoreTests {
    private func makeStore() -> (FileEpisodeStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return (FileEpisodeStore(fileURL: directory.appending(path: "cache.json")), directory)
    }

    @Test("Loading before anything is saved returns nil")
    func emptyStore() async throws {
        let (store, _) = makeStore()
        #expect(try await store.load() == nil)
    }

    @Test("A saved snapshot loads back unchanged")
    func roundTrip() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], nextPage: 2, refreshedAt: fixedDate)

        try await store.save(snapshot)

        #expect(try await store.load() == snapshot)
    }

    @Test("A cache saved before partial lists existed loads as a complete list")
    func cacheWithoutNextPage() async throws {
        struct OlderSnapshot: Encodable {
            let episodes: [Episode]
            let refreshedAt: Date
        }
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(OlderSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate))
        try data.write(to: directory.appending(path: "cache.json"))

        let loaded = try #require(try await store.load())

        #expect(loaded.episodes.map(\.id) == [1])
        #expect(loaded.nextPage == nil)
    }

    @Test("Works in folders whose names contain spaces, like Application Support")
    func pathWithSpaces() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Application Support \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileEpisodeStore(fileURL: directory.appending(path: "cache.json"))
        let snapshot = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)

        try await store.save(snapshot)

        #expect(try await store.load() == snapshot)
    }

    @Test("A corrupt file throws instead of returning bad data")
    func corruptFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "cache.json")
        try Data("not json".utf8).write(to: fileURL)

        await #expect(throws: (any Error).self) {
            try await FileEpisodeStore(fileURL: fileURL).load()
        }
    }
}
