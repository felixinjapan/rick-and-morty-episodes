import Foundation
import os

/// Shared by the UI and the background refresh task.
actor DefaultEpisodeRepository: EpisodeRepository {
    private let api: any RickAndMortyAPI
    private let store: FileEpisodeStore
    private let now: @Sendable () -> Date
    private let logger = Logger(category: "DefaultEpisodeRepository")
    private var latest: EpisodeSnapshot?

    init(
        api: any RickAndMortyAPI,
        store: FileEpisodeStore,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.api = api
        self.store = store
        self.now = now
    }

    func loadCurrentSnapshot() async -> EpisodeSnapshot? {
        do {
            if let saved = try await store.load(), saved.refreshedAt > (latest?.refreshedAt ?? .distantPast) {
                latest = saved
            }
        } catch {
            logger.error("Failed to read episode cache: \(error.localizedDescription, privacy: .public)")
        }
        return latest
    }

    func loadNextPage(after current: EpisodeSnapshot?) async throws -> EpisodeSnapshot {
        if let current, current.nextPage == nil { return current }
        let page = current?.nextPage ?? 1

        let loaded = try await translatingErrors(logger: logger) { try await api.episodes(page: page) }

        // A refresh replaced the list while this page loaded: drop the page, don't save over it.
        if latest != current, let latest {
            return latest
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

    func refreshFirstPage() async throws -> EpisodeSnapshot {
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
