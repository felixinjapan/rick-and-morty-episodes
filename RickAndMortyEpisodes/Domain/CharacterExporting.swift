import Foundation

/// Saves a character's details to a file another app can open. `CharacterExporter` implements it.
protocol CharacterExporting: Sendable {
    /// Writes the file and returns its location.
    func export(_ character: CharacterDetails) throws -> URL
}
