import CryptoKit
import Foundation

actor PortraitStore {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func load(for url: URL) throws -> Data? {
        try CacheFiles.read(fileURL(for: url))
    }

    func save(_ data: Data, for url: URL) throws {
        try CacheFiles.prepareDirectory(directory)
        try CacheFiles.write(data, to: fileURL(for: url))
    }

    private func fileURL(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: "\(hash).portrait")
    }
}
