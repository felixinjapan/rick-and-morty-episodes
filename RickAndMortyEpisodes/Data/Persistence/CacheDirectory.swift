import Foundation

/// A folder for files that can be downloaded again.
enum CacheDirectory {
    /// Creates the folder if needed and keeps it out of backups.
    static func prepare(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
