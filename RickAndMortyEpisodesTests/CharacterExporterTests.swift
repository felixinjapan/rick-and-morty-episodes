import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Character export")
struct CharacterExporterTests {
    @Test("The export contains exactly the required fields")
    func exportText() {
        #expect(CharacterExporter.text(for: .rick) == """
        Name: Rick Sanchez
        Status: Alive
        Species: Human
        Origin: Earth (C-137)
        Episodes: 51

        """)
    }

    @Test("File names are safe and identify the character", arguments: [
        ("Rick Sanchez", "Character-1-Rick-Sanchez.txt"),
        ("Mr. Poopybutthole", "Character-1-Mr-Poopybutthole.txt"),
        ("Rick/Morty: \"C-137\"", "Character-1-Rick-Morty-C-137.txt"),
        ("???", "Character-1-Unknown.txt"),
    ])
    func fileNames(name: String, expected: String) {
        let character = CharacterDetails(
            id: 1, name: name, status: .unknown, species: "", originName: "", episodeCount: 0, imageURL: nil
        )
        #expect(CharacterExporter.fileName(for: character) == expected)
    }

    @Test("Exporting writes a readable file, and re-exporting replaces it")
    func writesFile() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let exporter = CharacterExporter(directory: directory)

        let url = try exporter.export(.rick)
        _ = try exporter.export(.rick)

        #expect(try String(contentsOf: url, encoding: .utf8) == CharacterExporter.text(for: .rick))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)).count == 1)
    }
}
