import Foundation

/// The character details the detail screen needs, whatever their source.
/// `DefaultCharacterRepository` implements it. Throws `DataError`, or `CancellationError` when
/// the calling task is cancelled.
protocol CharacterRepository: Sendable {
    /// Details of one character.
    func character(id: Int) async throws -> CharacterDetails

    /// The character's portrait image data. Like the details, it is saved once the user has seen it.
    /// Throws `DataError.notFound` if the character has no portrait.
    func portrait(for character: CharacterDetails) async throws -> Data
}
