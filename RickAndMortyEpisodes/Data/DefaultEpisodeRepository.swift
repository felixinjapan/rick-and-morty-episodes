import Foundation
import os

/// The single source of truth for the episode list, shared by the UI and the background task.
/// An actor because both reach its mutable state (`latest`) at the same time.
actor DefaultEpisodeRepository: EpisodeRepository {
    private let api: any RickAndMortyAPI
    private let store: FileEpisodeStore
    private let now: @Sendable () -> Date
    private let logger = Logger(category: "DefaultEpisodeRepository")
    /// The list as last loaded, refreshed or read from disk.
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

    // MARK: - Episodes

    /// The saved list or the one last loaded, whichever is newer. At launch it reads the file;
    /// afterwards memory is normally current, because the background task uses this instance.
    /// An unreadable cache is logged and treated as no cache.
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

    /// See `EpisodeRepository`. Each page is saved as it arrives, so the list reopens where the
    /// user left it.
    func loadNextPage(after current: EpisodeSnapshot?) async throws -> EpisodeSnapshot {
        let page: Int
        if let current {
            guard let next = current.nextPage else { return current }
            page = next
        } else {
            page = 1
        }

        let loaded = try await translatingErrors(logger: logger) { try await api.episodes(page: page) }

        // A refresh replaced the list while this page loaded: drop the page, don't save over it.
        if latest != current, let latest {
            return latest
        }

        let snapshot = EpisodeSnapshot(
            episodes: (current?.episodes ?? []) + loaded.episodes,
            nextPage: loaded.hasNextPage ? page + 1 : nil,
            totalCount: loaded.totalCount,
            // "Last updated" and staleness refer to when page 1 was fetched.
            refreshedAt: current?.refreshedAt ?? now()
        )
        latest = snapshot
        await persist(snapshot)
        return snapshot
    }

    /// See `EpisodeRepository`. Cached pages after page 1 stay unless the catalogue shrank, and
    /// pages for newly added episodes load on scroll (see `EpisodeSnapshot.refreshed`).
    /// Overlapping refreshes aren't merged: each saves a valid list and the store writes
    /// them one at a time.
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
