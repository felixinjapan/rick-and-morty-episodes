import Foundation

/// Load failures throw `RepositoryError`; cancellation propagates as `CancellationError`.
protocol CharacterRepository: Sendable {
    func character(id: Int) async throws -> CharacterDetails

    /// Returns available details keyed by ID. Unavailable characters can still be opened by ID.
    func characters(ids: [Int]) async -> [Int: CharacterDetails]

    /// Throws `RepositoryError.notFound` if the character has no portrait.
    func portrait(for character: CharacterDetails) async throws -> Data
}
