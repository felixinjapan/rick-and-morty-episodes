import Foundation
import os

/// Shared by the UI and the background refresh task.
actor DefaultEpisodeRepository: EpisodeRepository, EpisodeCatalogue {
    private let api: any RickAndMortyAPI
    private let store: FileEpisodeStore
    private let now: @Sendable () -> Date
    private let logger = Logger(category: "DefaultEpisodeRepository")
    private var latest: EpisodeSnapshot?
    private var refresh: Task<EpisodeSnapshot, any Error>?
    /// Callers awaiting `refresh`; the request is cancelled only when all of them are.
    private(set) var refreshCallers = 0

    init(
        api: any RickAndMortyAPI,
        store: FileEpisodeStore,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.api = api
        self.store = store
        self.now = now
    }

    /// Every save goes through this actor, so once the list is in memory the file can't be newer
    /// and isn't read again.
    func loadCurrentSnapshot() async -> EpisodeSnapshot? {
        if let latest { return latest }
        do {
            let saved = try await store.load()
            // A refresh or page load may have finished while the file was read; keep its newer list.
            if latest == nil { latest = saved }
        } catch {
            logger.error("Failed to read episode cache: \(error.localizedDescription, privacy: .public)")
        }
        return latest
    }

    func knownEpisodeCount() async -> Int? {
        await loadCurrentSnapshot()?.totalCount
    }

    func loadNextPage() async throws -> EpisodeSnapshot {
        let current = await loadCurrentSnapshot()
        if let current, current.nextPage == nil { return current }
        let page = current?.nextPage ?? 1

        let loaded = try await translatingErrors(logger: logger) { try await api.episodes(page: page) }

        // A refresh replaced the list while this page loaded: drop the page, don't save over it.
        if latest != current, let latest {
            return latest
        }
        // Fewer episodes than when the earlier pages loaded: some were removed, so every later
        // episode moved back and this page would skip one. Start again from a fresh page 1.
        if let current, loaded.totalCount < current.totalCount {
            return try await refreshFirstPage()
        }

        let snapshot = EpisodeSnapshot(
            episodes: (current?.episodes ?? []) + loaded.episodes,
            nextPage: loaded.hasNextPage ? page + 1 : nil,
            totalCount: loaded.totalCount,
            refreshedAt: current?.refreshedAt ?? now()
        )
        latest = snapshot
        await persist(snapshot)
        return snapshot
    }

    /// Callers that overlap share one request: pull-to-refresh, the banner's Retry and the background
    /// task can all ask at once, and the actor interleaves them at each `await`.
    func refreshFirstPage() async throws -> EpisodeSnapshot {
        let task: Task<EpisodeSnapshot, any Error>
        if let running = refresh {
            task = running
        } else {
            task = Task {
                defer { refresh = nil; refreshCallers = 0 }
                return try await fetchFirstPage()
            }
            refresh = task
        }
        refreshCallers += 1
        // The request runs in its own task, so one caller leaving doesn't cancel it for the others.
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { await self.leaveRefresh(task) }
        }
    }

    private func leaveRefresh(_ task: Task<EpisodeSnapshot, any Error>) {
        guard refresh == task else { return }
        refreshCallers -= 1
        if refreshCallers == 0 { task.cancel() }
    }

    private func fetchFirstPage() async throws -> EpisodeSnapshot {
        // Read the saved list first: in a new process (the background task) memory is still empty,
        // and refreshing without it would save a list that has lost its cached pages.
        _ = await loadCurrentSnapshot()
        let firstPage = try await translatingErrors(logger: logger) { try await api.episodes(page: 1) }
        // Saved even if cancelled now: the page is valid and the write is small, so the request
        // isn't wasted. `latest` is read after the request, so a page loaded meanwhile is kept.
        let snapshot = EpisodeSnapshot.refreshed(latest, with: firstPage, at: now())
        latest = snapshot
        await persist(snapshot)
        return snapshot
    }

    /// A failed save only costs offline availability, so it is logged, not shown to the user.
    private func persist(_ snapshot: EpisodeSnapshot) async {
        do {
            try await store.save(snapshot)
        } catch {
            logger.error("Failed to save episode cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
