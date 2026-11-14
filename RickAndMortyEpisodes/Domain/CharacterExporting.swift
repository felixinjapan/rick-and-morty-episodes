import Foundation

/// Saves a character's details to a file another app can open.
/// `CharacterDetailViewModel` depends on this protocol; `CharacterExporter` in the Data layer
/// implements it with a plain-text file.
protocol CharacterExporting: Sendable {
    /// Writes the file and returns its location.
    func export(_ character: CharacterDetails) throws -> URL
}
