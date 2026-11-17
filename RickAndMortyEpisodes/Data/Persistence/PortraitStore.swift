import CryptoKit
import Foundation

actor PortraitStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    /// Application Support, not Caches: the system may empty Caches, and a portrait that was on screen
    /// should still be there offline.
    static func makeDefault() -> PortraitStore {
        PortraitStore(directory: URL.applicationSupportDirectory.appending(path: "portraits", directoryHint: .isDirectory))
    }

    func load(for url: URL) throws -> Data? {
        let fileURL = fileURL(for: url)
        // `path()` percent-encodes ("Application%20Support"), so the file would never be found.
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return nil }
        return try Data(contentsOf: fileURL)
    }

    func save(_ data: Data, for url: URL) throws {
        try CacheDirectory.prepare(directory)
        try data.write(to: fileURL(for: url), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func fileURL(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: "\(hash).portrait")
    }
}
