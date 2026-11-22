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
        Appears in: 51 episodes

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

    @Test("Exporting writes a readable file")
    func writesFile() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try CharacterExporter(directory: directory).export(.rick)

        #expect(try String(contentsOf: url, encoding: .utf8) == CharacterExporter.text(for: .rick))
    }

    @Test("Exporting a character again with changed details replaces the file")
    func reExportReplacesFile() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let exporter = CharacterExporter(directory: directory)
        let changed = CharacterDetails(
            id: CharacterDetails.rick.id, name: CharacterDetails.rick.name, status: .dead,
            species: CharacterDetails.rick.species, originName: CharacterDetails.rick.originName,
            episodeCount: CharacterDetails.rick.episodeCount + 1, imageURL: CharacterDetails.rick.imageURL
        )

        let first = try exporter.export(.rick)
        let second = try exporter.export(changed)

        #expect(second == first)
        #expect(try String(contentsOf: second, encoding: .utf8) == CharacterExporter.text(for: changed))
        #expect(CharacterExporter.text(for: changed) != CharacterExporter.text(for: .rick))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)).count == 1)
    }
}
