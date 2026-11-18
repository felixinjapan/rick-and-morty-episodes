import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("File character store")
struct FileCharacterStoreTests {
    private let saved = StoredCharacter(details: .rick, catalogueCount: 51, savedAt: fixedDate)

    @Test("A saved character reads back unchanged")
    func roundTrip() async throws {
        let store = FileCharacterStore.makeTemporary()
        try await store.save(saved)
        #expect(try await store.load(id: 1) == saved)
    }

    @Test("Every status survives saving", arguments: [CharacterStatus.alive, .dead, .unknown])
    func statusRoundTrip(status: CharacterStatus) async throws {
        let store = FileCharacterStore.makeTemporary()
        let details = CharacterDetails(
            id: 7, name: "X", status: status, species: "Alien", originName: "Y", episodeCount: 2, imageURL: nil
        )
        let stored = StoredCharacter(details: details, catalogueCount: nil, savedAt: fixedDate)

        try await store.save(stored)

        #expect(try await store.load(id: 7) == stored)
    }

    @Test("A batch saves and reads back several characters, reporting a missing one as nil")
    func batchRoundTrip() async throws {
        let store = FileCharacterStore.makeTemporary()
        let other = StoredCharacter(
            details: CharacterDetails(
                id: 2, name: "Morty", status: .alive, species: "Human", originName: "Earth", episodeCount: 3, imageURL: nil
            ),
            catalogueCount: nil, savedAt: fixedDate
        )

        let failures = await store.save([saved, other])
        let loaded = await store.load(ids: [1, 2, 3])

        #expect(failures.isEmpty)
        #expect(try loaded[1]?.get() == saved)
        #expect(try loaded[2]?.get() == other)
        #expect(try loaded[3]?.get() == nil)
    }

    @Test("A character that was never saved reads as missing")
    func missing() async throws {
        #expect(try await FileCharacterStore.makeTemporary().load(id: 1) == nil)
    }

    @Test("A file from another format version is treated as not saved")
    func otherFormatVersion() async throws {
        let directory = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/characters")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"version":99,"id":1}"#.utf8).write(to: directory.appending(path: "1.json"))

        #expect(try await FileCharacterStore(directory: directory).load(id: 1) == nil)
    }

    @Test("A file that can't be read is an error, not a missing character")
    func unreadableFile() async throws {
        let directory = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/characters")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appending(path: "1.json"))

        await #expect(throws: (any Error).self) { try await FileCharacterStore(directory: directory).load(id: 1) }
    }

    @Test("Each character has its own file, so saving one leaves the others alone")
    func oneFilePerCharacter() async throws {
        let directory = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/characters")
        let store = FileCharacterStore(directory: directory)
        let other = StoredCharacter(
            details: CharacterDetails(
                id: 2, name: "Morty Smith", status: .alive, species: "Human", originName: "unknown",
                episodeCount: 51, imageURL: nil
            ),
            catalogueCount: 51, savedAt: fixedDate
        )
        try await store.save(saved)
        try await store.save(other)
        let otherBefore = try Data(contentsOf: directory.appending(path: "2.json"))

        try await store.save(StoredCharacter(details: .rick, catalogueCount: 52, savedAt: fixedDate))

        #expect(try Data(contentsOf: directory.appending(path: "2.json")) == otherBefore)
        #expect(try await store.load(id: 1)?.catalogueCount == 52)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) == ["1.json", "2.json"])
    }

    @Test("Works in folders whose names contain spaces, like Application Support")
    func pathWithSpaces() async throws {
        let directory = URL.temporaryDirectory.appending(path: "Application Support \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileCharacterStore(directory: directory.appending(path: "characters"))

        try await store.save(saved)

        #expect(try await store.load(id: 1) == saved)
    }
}
