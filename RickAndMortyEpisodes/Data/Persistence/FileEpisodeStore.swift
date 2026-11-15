import Foundation

/// Saves the episode list as one JSON file. About 50 records, always read and written whole,
/// so a database would add nothing.
///
/// An actor, so concurrent saves can't interleave; `.atomic` writes never leave half a file.
/// No protocol: tests use a temporary folder and exercise real file I/O.
actor FileEpisodeStore {
    static let defaultFileName = "episodes-cache.json"

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Application Support, not Documents: Documents is shown in the Files app and holds the exports.
    static func makeDefault() -> FileEpisodeStore {
        let directory = URL.applicationSupportDirectory
        return FileEpisodeStore(fileURL: directory.appending(path: defaultFileName))
    }

    /// The saved list, or `nil` if there is none or it was written in another format version.
    /// Throws if the file exists but can't be read.
    func load() throws -> EpisodeSnapshot? {
        // `path()` percent-encodes ("Application%20Support"), so the file would never be found.
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: fileURL)
        // Read the version first: another format version is not an error, it counts as no cache.
        struct VersionOnly: Decodable { let version: Int? }
        let version = try JSONDecoder().decode(VersionOnly.self, from: data).version
        guard version == CachedEpisodeSnapshot.currentVersion else { return nil }
        return try JSONDecoder().decode(CachedEpisodeSnapshot.self, from: data).toDomain()
    }

    func save(_ snapshot: EpisodeSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(CachedEpisodeSnapshot(snapshot))
        // Not `.completeFileProtection`: the background task must be able to write while the device is locked.
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])

        // The cache can be downloaded again, so keep it out of backups.
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
