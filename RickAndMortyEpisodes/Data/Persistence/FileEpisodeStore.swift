import Foundation

actor FileEpisodeStore {
    static let defaultFileName = "episodes-cache.json"

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The saved list, or `nil` if there is none or it was written in another format version.
    /// Throws if the file exists but can't be read.
    func load() throws -> EpisodeSnapshot? {
        try CacheFiles.load(CachedEpisodeSnapshot.self, from: fileURL, version: CachedEpisodeSnapshot.currentVersion)?
            .toDomain()
    }

    func save(_ snapshot: EpisodeSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(CachedEpisodeSnapshot(snapshot))
        try CacheFiles.write(data, to: fileURL)
        CacheFiles.excludeFromBackup(fileURL)
    }
}
