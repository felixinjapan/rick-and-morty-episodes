import Foundation

actor FileCharacterStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// The saved character, or `nil` if there is none or it was written in another format version.
    /// Throws if the file exists but can't be read.
    func load(id: Int) throws -> StoredCharacter? {
        try CacheFiles.load(CachedCharacter.self, from: fileURL(for: id), version: CachedCharacter.currentVersion)?
            .toDomain()
    }

    func save(_ character: StoredCharacter) throws {
        try CacheFiles.prepareDirectory(directory)
        let data = try JSONEncoder().encode(CachedCharacter(character))
        try CacheFiles.write(data, to: fileURL(for: character.details.id))
    }

    private func fileURL(for id: Int) -> URL {
        directory.appending(path: "\(id).json")
    }
}
