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

    /// Reads several characters in one actor hop. A failure affects only the ID it belongs to.
    func load(ids: [Int]) -> [Int: Result<StoredCharacter?, any Error>] {
        Dictionary(uniqueKeysWithValues: ids.map { id in (id, Result { try load(id: id) }) })
    }

    /// Writes several characters in one actor hop and returns the failures by ID.
    func save(_ characters: [StoredCharacter]) -> [Int: any Error] {
        var failures: [Int: any Error] = [:]
        do {
            try CacheFiles.prepareDirectory(directory)
        } catch {
            return Dictionary(uniqueKeysWithValues: characters.map { ($0.details.id, error) })
        }
        for character in characters {
            do {
                try CacheFiles.write(JSONEncoder().encode(CachedCharacter(character)), to: fileURL(for: character.details.id))
            } catch {
                failures[character.details.id] = error
            }
        }
        return failures
    }

    private func fileURL(for id: Int) -> URL {
        directory.appending(path: "\(id).json")
    }
}
