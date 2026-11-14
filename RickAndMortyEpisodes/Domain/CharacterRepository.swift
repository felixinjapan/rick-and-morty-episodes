import Foundation

/// The character details the features need, independent of where they come from.
/// `CharacterDetailViewModel` depends on this protocol; `DefaultCharacterRepository` in the
/// Data layer implements it with the API.
///
/// Throws `DataError`, or `CancellationError` when the calling task is cancelled.
protocol CharacterRepository: Sendable {
    /// Details of one character.
    func character(id: Int) async throws -> CharacterDetails
}
