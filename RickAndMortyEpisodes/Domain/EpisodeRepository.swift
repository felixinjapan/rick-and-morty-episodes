import Foundation

/// The episode list the features need, independent of where it comes from.
/// View models depend on this protocol; `DefaultEpisodeRepository` in the Data layer
/// implements it with the API and the file cache.
///
/// Throwing methods throw `DataError`, or `CancellationError` when the calling task
/// is cancelled.
protocol EpisodeRepository: Sendable {
    /// The list to show: the saved one or the one last loaded, whichever is newer.
    /// `nil` when there is neither.
    func currentSnapshot() async -> EpisodeSnapshot?

    /// Loads the page after `current` (page 1 when `current` is `nil`), appends it, saves
    /// the result and returns it. If a refresh replaced the list while the page was
    /// loading, the page is dropped and the newer list is returned instead.
    func loadNextPage(after current: EpisodeSnapshot?) async throws -> EpisodeSnapshot

    /// Fetches page 1 and saves it as the new start of the list. Deeper pages load again
    /// as the user scrolls, so a refresh costs one request however many pages exist.
    func refreshFirstPage() async throws -> EpisodeSnapshot
}
