import Foundation
import os

/// The app's `EpisodeRepository`: the single source of truth for episode and character data.
/// Decides what comes from the network and what comes from the cache, and is shared by the
/// UI and background refresh.
///
/// An actor because it holds mutable state (the character cache) that is reached from
/// the main actor and from the background task at the same time.
actor DefaultEpisodeRepository: EpisodeRepository {
    private let api: any RickAndMortyAPI
    private let store: FileEpisodeStore
    private let now: @Sendable () -> Date
    private let logger = Logger(subsystem: "RickAndMortyEpisodes", category: "DefaultEpisodeRepository")
    private var characterCache: [Int: CharacterDetails] = [:]

    init(
        api: any RickAndMortyAPI,
        store: FileEpisodeStore,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.api = api
        self.store = store
        self.now = now
    }

    // MARK: - Episodes

    /// The persisted list, or `nil` if there is none or it can't be read.
    /// A corrupt cache isn't fatal: the app falls back to loading from the network.
    func cachedSnapshot() async -> EpisodeSnapshot? {
        do {
            return try await store.load()
        } catch {
            logger.error("Failed to read episode cache: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// One page for incremental loading while the user scrolls (first launch, no cache yet).
    func episodesPage(_ page: Int) async throws -> EpisodePage {
        try await translatingErrors { try await api.episodes(page: page) }
    }

    /// Persists a list that was fully loaded page by page.
    func save(_ snapshot: EpisodeSnapshot) async throws {
        try await translatingErrors { try await store.save(snapshot) }
    }

    /// Fetches every page and replaces the cache as one unit.
    ///
    /// Overlapping refreshes (e.g. pull-to-refresh while the background task runs) are
    /// not merged: each fetches a complete list, and the store writes them one at a time,
    /// so the cache always holds a complete list.
    func refreshAll() async throws -> EpisodeSnapshot {
        try await translatingErrors { try await fetchAndSaveAllPages() }
    }

    private func fetchAndSaveAllPages() async throws -> EpisodeSnapshot {
        let api = self.api
        let firstPage = try await api.episodes(page: 1)
        var pages: [Int: [Episode]] = [1: firstPage.episodes]

        // The first page tells us how many pages exist; fetch the rest in parallel.
        if firstPage.pageCount > 1 {
            try await withThrowingTaskGroup(of: (Int, [Episode]).self) { group in
                for page in 2...firstPage.pageCount {
                    group.addTask { (page, try await api.episodes(page: page).episodes) }
                }
                for try await (page, episodes) in group {
                    pages[page] = episodes
                }
            }
        }

        // Never persist a partial result: if anything failed or was cancelled, the
        // previous snapshot stays as it was.
        try Task.checkCancellation()

        let episodes = pages.keys.sorted().flatMap { pages[$0] ?? [] }
        let snapshot = EpisodeSnapshot(episodes: episodes, refreshedAt: now())
        try await store.save(snapshot)
        return snapshot
    }

    // MARK: - Characters

    /// Character details, kept in memory for the session so going back and forth
    /// between screens doesn't re-download them.
    func character(id: Int) async throws -> CharacterDetails {
        if let cached = characterCache[id] {
            return cached
        }
        let character = try await translatingErrors { try await api.character(id: id) }
        characterCache[id] = character
        return character
    }

    // MARK: - Errors

    /// Runs `operation` and rethrows its failure as an `EpisodeError`, so nothing above the
    /// Data layer depends on HTTP or URL-loading errors. Cancellation passes through unchanged.
    private func translatingErrors<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            logger.error("Request failed: \(String(describing: error), privacy: .public)")
            throw Self.domainError(for: error)
        }
    }

    static func domainError(for error: any Error) -> EpisodeError {
        guard let apiError = error as? APIError else { return .failed }
        switch apiError {
        case .offline: return .offline
        case .timedOut: return .timedOut
        case .http(404): return .notFound
        case .http(429): return .rateLimited
        case .http(let status) where status >= 500: return .serverUnavailable
        case .invalidResponse: return .serverUnavailable
        case .decoding: return .unreadableData
        case .transport, .http: return .failed
        }
    }
}
