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
        let snapshot = EpisodeSnapshot(episodes: [.make(id: 1), .make(id: 2)], refreshedAt: fixedDate)

        try await store.save(snapshot)

        #expect(try await store.load() == snapshot)
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

    @Test("A cancelled save leaves the previous snapshot intact")
    func cancelledSaveKeepsPreviousSnapshot() async throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let previous = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate)
        try await store.save(previous)
        let gate = Gate()
        let save = Task {
            await gate.wait()
            try await store.save(EpisodeSnapshot(episodes: [.make(id: 2)], refreshedAt: .now))
        }
        save.cancel()
        await gate.open()

        await #expect(throws: CancellationError.self) { try await save.value }
        #expect(try await store.load() == previous)
    }
}
