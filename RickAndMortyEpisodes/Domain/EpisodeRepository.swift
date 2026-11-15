import Foundation

/// The episode list the view models need, whatever its source. `DefaultEpisodeRepository`
/// implements it. Throws `DataError`, or `CancellationError` when the calling task is cancelled.
/// Saving is best effort: a failed write is logged, not thrown, so a returned list may not be on disk.
protocol EpisodeRepository: Sendable {
    /// The saved list or the one last loaded, whichever is newer; `nil` if there is neither.
    func loadCurrentSnapshot() async -> EpisodeSnapshot?

    /// Loads the page after `current` (page 1 if `nil`), appends it, saves and returns the list.
    /// If a refresh replaced the list meanwhile, the page is dropped and the newer list returned.
    func loadNextPage(after current: EpisodeSnapshot?) async throws -> EpisodeSnapshot

    /// Fetches page 1 and saves it as the new start of the list: one request however many pages exist.
    func refreshFirstPage() async throws -> EpisodeSnapshot
}
