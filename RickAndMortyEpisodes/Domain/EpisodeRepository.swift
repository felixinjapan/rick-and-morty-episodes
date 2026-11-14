import Foundation

/// The episode and character data the features need, independent of where it comes from.
/// View models depend on this protocol; `DefaultEpisodeRepository` in the Data layer
/// implements it with the API and the file cache.
///
/// Throwing methods throw `EpisodeError`, or `CancellationError` when the calling task
/// is cancelled.
protocol EpisodeRepository: Sendable {
    /// The persisted list, or `nil` if there is none or it can't be read.
    func cachedSnapshot() async -> EpisodeSnapshot?

    /// One page for incremental loading while the user scrolls (first launch, no cache yet).
    func episodesPage(_ page: Int) async throws -> EpisodePage

    /// Persists the pages loaded so far.
    func save(_ snapshot: EpisodeSnapshot) async throws

    /// Fetches page 1 and saves it as the new start of the list. Deeper pages load again
    /// as the user scrolls, so a refresh costs one request however many pages exist.
    func refreshFirstPage() async throws -> EpisodeSnapshot

    /// Details of one character.
    func character(id: Int) async throws -> CharacterDetails
}
