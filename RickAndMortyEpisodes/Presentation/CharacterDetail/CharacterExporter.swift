import Foundation

/// Writes a character's details to a plain-text file in the app's Documents/Exports folder.
///
/// Documents is exposed in the Files app (`UIFileSharingEnabled` and
/// `LSSupportsOpeningDocumentsInPlace` in Info.plist), so the file can be opened from
/// Files › On My iPhone › Episodes, or handed to another app through the share sheet.
struct CharacterExporter {
    let directory: URL

    static let `default` = CharacterExporter(
        directory: URL.documentsDirectory.appending(path: "Exports", directoryHint: .isDirectory)
    )

    /// The file contents. Kept separate from file I/O so it can be tested directly.
    static func text(for character: CharacterDetails) -> String {
        """
        Name: \(character.name)
        Status: \(character.status)
        Species: \(character.species)
        Origin: \(character.originName)
        Episodes: \(character.episodeCount)

        """
    }

    /// e.g. "Character-1-Rick-Sanchez.txt". Exporting the same character again replaces the file.
    static func fileName(for character: CharacterDetails) -> String {
        let allowed = CharacterSet.alphanumerics
        let words = character.name.unicodeScalars
            .map { allowed.contains($0) ? String($0) : " " }
            .joined()
            .split(separator: " ")
        let slug = words.isEmpty ? "Unknown" : words.joined(separator: "-")
        return "Character-\(character.id)-\(slug).txt"
    }

    func export(_ character: CharacterDetails) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: Self.fileName(for: character))
        try Self.text(for: character).write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
