import Foundation
import os

/// The app's `EpisodeRepository`: the single source of truth for the episode list.
/// Decides what comes from the network and what comes from the cache, and is shared by the
/// UI and background refresh.
///
/// An actor because it holds mutable state (the latest list) that is reached from
/// the main actor and from the background task at the same time.
actor DefaultEpisodeRepository: EpisodeRepository {
    private let api: any RickAndMortyAPI
    private let store: FileEpisodeStore
    private let now: @Sendable () -> Date
    private let logger = Logger(category: "DefaultEpisodeRepository")
    /// The list as last loaded, refreshed or read from disk. A page is only appended to
    /// this list, so a page that arrives after a refresh can't overwrite the newer list.
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

    /// The list to show: the saved one or the one last loaded, whichever is newer. The disk
    /// can be newer when a background refresh saved while the app was suspended.
    /// A corrupt cache isn't fatal: the app falls back to loading from the network.
    func currentSnapshot() async -> EpisodeSnapshot? {
        do {
            if let saved = try await store.load(), saved.refreshedAt > (latest?.refreshedAt ?? .distantPast) {
                latest = saved
            }
        } catch {
            logger.error("Failed to read episode cache: \(error.localizedDescription, privacy: .public)")
        }
        return latest
    }

    /// Loads the page after `current` (page 1 when `current` is `nil`), appends it, saves
    /// the result and returns it. Each page is saved as it arrives, so the list reopens
    /// where the user left it.
    func loadNextPage(after current: EpisodeSnapshot?) async throws -> EpisodeSnapshot {
        let page: Int
        if let current {
            guard let next = current.nextPage else { return current }
            page = next
        } else {
            page = 1
        }

        let loaded = try await translatingErrors(logger: logger) { try await api.episodes(page: page) }

        // A refresh replaced the list while this page was loading: drop the page and
        // return the newer list, instead of saving the old one over it.
        if latest != current, let latest {
            return latest
        }

        let snapshot = EpisodeSnapshot(
            episodes: (current?.episodes ?? []) + loaded.episodes,
            nextPage: loaded.hasNextPage ? page + 1 : nil,
            // "Last updated" and the staleness check refer to when page 1 was fetched.
            refreshedAt: current?.refreshedAt ?? now()
        )
        latest = snapshot
        await persist(snapshot)
        return snapshot
    }

    /// Fetches page 1 and saves it as the new start of the list. Pages the user had loaded
    /// beyond it are dropped from the cache; they load again as the user scrolls.
    ///
    /// One request however many pages the API has, so it also fits easily in the short
    /// time a background task gets. Overlapping refreshes are not merged: each saves a
    /// valid first page, and the store writes them one at a time.
    func refreshFirstPage() async throws -> EpisodeSnapshot {
        let firstPage = try await translatingErrors(logger: logger) { try await api.episodes(page: 1) }
        // Saved even if cancellation arrives now: the page is valid, and saving it is one
        // small atomic write, so the request isn't wasted.
        let snapshot = EpisodeSnapshot(
            episodes: firstPage.episodes,
            nextPage: firstPage.hasNextPage ? 2 : nil,
            refreshedAt: now()
        )
        latest = snapshot
        await persist(snapshot)
        return snapshot
    }

    /// Saves the list. A failed save only means it won't be available offline, so it is
    /// logged rather than reported to the user.
    private func persist(_ snapshot: EpisodeSnapshot) async {
        do {
            try await store.save(snapshot)
        } catch {
            logger.error("Failed to save episode cache: \(error.localizedDescription, privacy: .public)")
        }
    }
}
