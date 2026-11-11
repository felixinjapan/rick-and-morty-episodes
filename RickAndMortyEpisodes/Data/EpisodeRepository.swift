import Foundation
import os

/// Single source of truth for episode and character data. Decides what comes from the
/// network and what comes from the cache, and is shared by the UI and background refresh.
///
/// An actor because it holds mutable state (the in-flight refresh and the character cache)
/// that is reached from the main actor and from the background task at the same time.
actor EpisodeRepository {
    private let api: any RickAndMortyAPI
    private let store: any EpisodeStore
    private let now: @Sendable () -> Date
    private let logger = Logger(subsystem: "RickAndMortyEpisodes", category: "EpisodeRepository")

    private struct Refresh {
        let id: UUID
        let task: Task<Void, Never>
        var waiters: [UUID: CheckedContinuation<EpisodeSnapshot, Error>]
    }

    private var inFlightRefresh: Refresh?
    private var characterCache: [Int: CharacterDetails] = [:]

    #if DEBUG
    /// Lets concurrency tests observe admission rather than guess scheduler timing.
    var refreshWaiterCount: Int { inFlightRefresh?.waiters.count ?? 0 }
    #endif

    init(
        api: any RickAndMortyAPI,
        store: any EpisodeStore,
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
        try await api.episodes(page: page)
    }

    /// Persists a list that was fully loaded page by page.
    func saveCompleteList(_ episodes: [Episode]) async throws -> EpisodeSnapshot {
        let snapshot = EpisodeSnapshot(episodes: episodes, refreshedAt: now())
        try await store.save(snapshot)
        return snapshot
    }

    /// Fetches every page and replaces the cache as one unit.
    ///
    /// Concurrent callers (pull-to-refresh and the background task) share the same request
    /// instead of fetching twice and racing to write the cache.
    func refreshAll() async throws -> EpisodeSnapshot {
        let waiterID = UUID()
        let snapshot = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                if inFlightRefresh != nil {
                    inFlightRefresh?.waiters[waiterID] = continuation
                } else {
                    let refreshID = UUID()
                    let task = Task {
                        let result: Result<EpisodeSnapshot, Error>
                        do { result = .success(try await self.fetchAllAndSave()) }
                        catch { result = .failure(error) }
                        self.finishRefresh(id: refreshID, result: result)
                    }
                    inFlightRefresh = Refresh(id: refreshID, task: task, waiters: [waiterID: continuation])
                }
            }
        } onCancel: {
            Task { await self.cancelRefreshWaiter(id: waiterID) }
        }
        try Task.checkCancellation()
        return snapshot
    }

    private func cancelRefreshWaiter(id: UUID) {
        guard let waiter = inFlightRefresh?.waiters.removeValue(forKey: id) else { return }
        waiter.resume(throwing: CancellationError())
        if inFlightRefresh?.waiters.isEmpty == true {
            inFlightRefresh?.task.cancel()
            inFlightRefresh = nil
        }
    }

    private func finishRefresh(id: UUID, result: Result<EpisodeSnapshot, Error>) {
        guard let refresh = inFlightRefresh, refresh.id == id else { return }
        inFlightRefresh = nil
        for waiter in refresh.waiters.values {
            waiter.resume(with: result)
        }
    }

    private func fetchAllAndSave() async throws -> EpisodeSnapshot {
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
        let character = try await api.character(id: id)
        characterCache[id] = character
        return character
    }
}
