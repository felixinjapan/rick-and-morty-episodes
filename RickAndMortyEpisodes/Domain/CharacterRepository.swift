import Foundation

/// Load failures throw `DataError`; cancellation propagates as `CancellationError`.
protocol CharacterRepository: Sendable {
    func character(id: Int) async throws -> CharacterDetails

    /// Throws `DataError.notFound` if the character has no portrait.
    func portrait(for character: CharacterDetails) async throws -> Data
}
