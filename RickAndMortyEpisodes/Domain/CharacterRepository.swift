import Foundation

/// The character details the detail screen needs, whatever their source.
/// `DefaultCharacterRepository` implements it. Throws `DataError`, or `CancellationError` when
/// the calling task is cancelled.
protocol CharacterRepository: Sendable {
    /// Details of one character.
    func character(id: Int) async throws -> CharacterDetails
}
