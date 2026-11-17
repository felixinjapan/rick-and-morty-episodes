import Foundation

actor FileCharacterStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    static func makeDefault() -> FileCharacterStore {
        FileCharacterStore(directory: URL.applicationSupportDirectory.appending(path: "characters", directoryHint: .isDirectory))
    }

    /// The saved character, or `nil` if there is none or it was written in another format version.
    /// Throws if the file exists but can't be read.
    func load(id: Int) throws -> StoredCharacter? {
        let fileURL = fileURL(for: id)
        // `path()` percent-encodes ("Application%20Support"), so the file would never be found.
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: fileURL)
        struct VersionOnly: Decodable { let version: Int? }
        let version = try JSONDecoder().decode(VersionOnly.self, from: data).version
        guard version == CachedCharacter.currentVersion else { return nil }
        return try JSONDecoder().decode(CachedCharacter.self, from: data).toDomain()
    }

    func save(_ character: StoredCharacter) throws {
        try CacheDirectory.prepare(directory)
        let data = try JSONEncoder().encode(CachedCharacter(character))
        try data.write(
            to: fileURL(for: character.details.id),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    private func fileURL(for id: Int) -> URL {
        directory.appending(path: "\(id).json")
    }
}
