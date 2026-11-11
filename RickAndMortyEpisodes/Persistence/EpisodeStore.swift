import Foundation

/// Persists the episode list. A protocol so the repository can be tested with an
/// in-memory store and the file format can change without touching callers.
protocol EpisodeStore: Sendable {
    func load() async throws -> EpisodeSnapshot?
    func save(_ snapshot: EpisodeSnapshot) async throws
}

/// Saves the whole snapshot as one JSON file.
///
/// The data is ~50 records that are always read and written as a whole, with no queries
/// or relationships, so a database (SwiftData/Core Data) would add complexity without benefit.
/// The actor serialises access so concurrent saves (pull-to-refresh and background refresh)
/// can't interleave, and `.atomic` writes mean a crash never leaves a half-written file.
actor FileEpisodeStore: EpisodeStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Application Support, not Documents: Documents is visible in the Files app
    /// (it holds exports), while the cache is an internal detail.
    static func makeDefault() -> FileEpisodeStore {
        let directory = URL.applicationSupportDirectory
        return FileEpisodeStore(fileURL: directory.appending(path: "episodes-cache.json"))
    }

    func load() throws -> EpisodeSnapshot? {
        // `path(percentEncoded: false)`: the default `path()` percent-encodes, so
        // "Application Support" would become "Application%20Support" and never be found.
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(EpisodeSnapshot.self, from: data)
    }

    func save(_ snapshot: EpisodeSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(snapshot)
        // `.completeFileProtectionUntilFirstUserAuthentication`: background refresh must be able
        // to write while the device is locked, which `.completeFileProtection` would prevent.
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])

        // The cache can be re-downloaded, so keep it out of iCloud backups.
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
