import Foundation

enum CacheFiles {
    static func prepareDirectory(_ directory: URL) throws {
        guard !FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        excludeFromBackup(directory)
    }

    static func read(_ url: URL) throws -> Data? {
        // Use the decoded path for folders such as Application Support.
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        return try Data(contentsOf: url)
    }

    static func load<Value: Decodable>(_ type: Value.Type, from url: URL, version: Int) throws -> Value? {
        guard let data = try read(url) else { return nil }
        let decoder = JSONDecoder()
        guard try decoder.decode(VersionOnly.self, from: data).version == version else { return nil }
        return try decoder.decode(type, from: data)
    }

    private struct VersionOnly: Decodable {
        let version: Int?
    }

    static func write(_ data: Data, to url: URL) throws {
        // Background refresh needs to write while the device is locked after its first unlock.
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
