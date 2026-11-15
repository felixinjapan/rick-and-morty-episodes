import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Portrait store")
struct PortraitStoreTests {
    private let url = URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")!

    @Test("A saved portrait reads back unchanged")
    func roundTrip() async throws {
        let store = PortraitStore.makeTemporary()
        try await store.save(RecordedResponses.portrait, for: url)
        #expect(try await store.load(for: url) == RecordedResponses.portrait)
    }

    @Test("A portrait that was never saved reads as missing")
    func missing() async throws {
        #expect(try await PortraitStore.makeTemporary().load(for: url) == nil)
    }

    @Test("Each URL has its own file")
    func oneFilePerURL() async throws {
        let store = PortraitStore.makeTemporary()
        let other = URL(string: "https://rickandmortyapi.com/api/character/avatar/2.jpeg")!
        try await store.save(Data("one".utf8), for: url)
        try await store.save(Data("two".utf8), for: other)

        #expect(try await store.load(for: url) == Data("one".utf8))
        #expect(try await store.load(for: other) == Data("two".utf8))
    }

    @Test("Works in folders whose names contain spaces, like Application Support")
    func pathWithSpaces() async throws {
        let directory = URL.temporaryDirectory.appending(path: "Application Support \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PortraitStore(directory: directory.appending(path: "portraits"))

        try await store.save(RecordedResponses.portrait, for: url)

        #expect(try await store.load(for: url) == RecordedResponses.portrait)
    }
}
