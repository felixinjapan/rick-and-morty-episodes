import Foundation

/// Load failures throw `RepositoryError`; cancellation propagates as `CancellationError`.
protocol PortraitRepository: Sendable {
    /// Throws `RepositoryError.notFound` if the character has no portrait.
    func portrait(for character: CharacterDetails) async throws -> Data
}
