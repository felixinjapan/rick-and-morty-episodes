import Foundation

struct CharacterExporter: CharacterExporting {
    let directory: URL

    static func text(for character: CharacterDetails) -> String {
        """
        Name: \(character.name)
        Status: \(exportValue(of: character.status))
        Species: \(character.species)
        Origin: \(character.originName)
        Episodes: \(character.episodeCount)

        """
    }

    static func fileName(for character: CharacterDetails) -> String {
        let words = character.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
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
