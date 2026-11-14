import Foundation

/// Writes a character's details to a plain-text file in `directory`. The app passes
/// Documents/Exports (see `AppDependencies.makeExporter()`), which the Files app shows.
struct CharacterExporter: CharacterExporting {
    let directory: URL

    /// The file contents. Kept separate from file I/O so it can be tested directly.
    static func text(for character: CharacterDetails) -> String {
        """
        Name: \(character.name)
        Status: \(exportValue(of: character.status))
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

    /// The export is a fixed-format file other apps read, so it keeps the API's English
    /// wording regardless of the app's language.
    private static func exportValue(of status: CharacterStatus) -> String {
        switch status {
        case .alive: "Alive"
        case .dead: "Dead"
        case .unknown: "unknown"
        }
    }
}
