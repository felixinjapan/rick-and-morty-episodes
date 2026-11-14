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
    private let logger = Logger(category: "DefaultEpisodeRepository")
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

    /// Fetches page 1 and saves it as the new start of the list. Pages the user had loaded
    /// beyond it are dropped from the cache; they load again as the user scrolls.
    ///
    /// One request however many pages the API has, so it also fits easily in the short
    /// time a background task gets. Overlapping refreshes are not merged: each saves a
    /// valid first page, and the store writes them one at a time.
    func refreshFirstPage() async throws -> EpisodeSnapshot {
        try await translatingErrors {
            let firstPage = try await api.episodes(page: 1)
            // A cancelled refresh (for example, a background task out of time) saves nothing.
            try Task.checkCancellation()
            let snapshot = EpisodeSnapshot(
                episodes: firstPage.episodes,
                nextPage: firstPage.hasNextPage ? 2 : nil,
                refreshedAt: now()
            )
            try await store.save(snapshot)
            return snapshot
        }
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
