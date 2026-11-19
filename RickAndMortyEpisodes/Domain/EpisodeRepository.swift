import Foundation

/// Load failures throw `RepositoryError`; cancellation propagates as `CancellationError`.
/// Saving is best effort: a returned snapshot may not have reached disk.
protocol EpisodeRepository: Sendable {
    /// The saved list or the one last loaded, whichever is newer; `nil` if there is neither.
    func loadCurrentSnapshot() async -> EpisodeSnapshot?

    /// Loads the page after `current` (page 1 if `nil`), appends it, saves and returns the list.
    /// If a refresh replaced the list meanwhile, the page is dropped and the newer list returned.
    func loadNextPage(after current: EpisodeSnapshot?) async throws -> EpisodeSnapshot

    /// Fetches page 1 and saves it as the new start of the list: one request however many pages exist.
    /// The cached pages after it stay while the catalogue is the same size; if it grew, the list ends
    /// at the last whole page and the new episodes load as the user scrolls.
    /// Calls that overlap share one request, which is cancelled only when every caller has been.
    func refreshFirstPage() async throws -> EpisodeSnapshot
}
