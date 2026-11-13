import Foundation
import Observation

/// State and behaviour of the episode list: incremental paging, cached content,
/// pull-to-refresh and the "last updated" timestamp.
///
/// Main-actor isolated because SwiftUI reads it. Being on one actor also makes the
/// "is a page already loading?" check-and-set atomic, which prevents duplicate page requests.
@MainActor
@Observable
final class EpisodeListViewModel {
    enum Footer: Equatable {
        /// The cache hasn't been checked yet, or the error is shown full screen.
        case none
        /// More pages exist; the footer triggers loading this page when it appears.
        case loading(page: Int)
        case failed(message: String)
        case endReached(count: Int)
    }

    private(set) var episodes: [Episode] = []
    private(set) var lastRefreshed: Date?
    var isRefreshing: Bool { activeRefreshCount > 0 }
    /// Shown as a banner when a refresh fails but older content is still on screen.
    private(set) var refreshError: String?

    private var nextPage: Int?
    private var pageError: String?
    private var isLoadingPage = false
    private var hasStarted = false
    private var hasCheckedCache = false
    private var activeRefreshCount = 0
    /// Incremented whenever the whole list is replaced, so a page request that was
    /// started before a refresh can't append stale results to the new list.
    private var listGeneration = 0

    private let repository: any EpisodeRepository
    private let staleInterval: TimeInterval
    private let now: () -> Date

    init(
        repository: any EpisodeRepository,
        staleInterval: TimeInterval = 60 * 60,
        now: @escaping () -> Date = { .now }
    ) {
        self.repository = repository
        self.staleInterval = staleInterval
        self.now = now
    }

    /// A loading error while no episodes are on screen. The view shows it full screen
    /// instead of in the footer row.
    var emptyListError: String? {
        episodes.isEmpty ? pageError : nil
    }

    var footer: Footer {
        guard hasCheckedCache, emptyListError == nil else { return .none }
        if let pageError { return .failed(message: pageError) }
        if let nextPage { return .loading(page: nextPage) }
        return .endReached(count: episodes.count)
    }

    // MARK: - Lifecycle

    /// Shows cached content immediately if there is any, then refreshes it if it's stale.
    /// Without a cache, the footer's `.loading(page: 1)` state starts incremental loading.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        if let snapshot = await repository.cachedSnapshot() {
            apply(snapshot)
        } else {
            nextPage = 1
        }
        hasCheckedCache = true

        if isStale {
            await refresh()
        }
    }

    /// Brings the list up to date: shows a newer snapshot saved by a background refresh,
    /// then refreshes from the network if the data is still stale. The app calls this
    /// when it returns to the foreground.
    func refreshIfNeeded() async {
        guard hasCheckedCache else { return }
        if let snapshot = await repository.cachedSnapshot(),
           snapshot.refreshedAt > (lastRefreshed ?? .distantPast) {
            apply(snapshot)
        }
        if isStale {
            await refresh()
        }
    }

    // MARK: - Paging

    func loadNextPage() async {
        guard !isLoadingPage, let page = nextPage else { return }
        isLoadingPage = true
        pageError = nil
        let generation = listGeneration
        let repository = self.repository

        // The results belong to the view model, not to the footer view that triggered the load.
        // Running the request in its own task means scrolling the footer off screen
        // (which cancels the view's `.task`) doesn't cancel and restart the request.
        let result = await Task { try await repository.episodesPage(page) }.result

        guard generation == listGeneration else { return }
        isLoadingPage = false

        switch result {
        case .success(let loaded):
            episodes += loaded.episodes
            nextPage = loaded.hasNextPage ? page + 1 : nil
            if nextPage == nil {
                await saveCompleteList()
            }
        case .failure(let error):
            pageError = error.userMessage
        }
    }

    // MARK: - Refresh

    /// Re-fetches the full list. Used by pull-to-refresh and when cached data is stale.
    func refresh() async {
        activeRefreshCount += 1
        defer { activeRefreshCount -= 1 }

        do {
            let snapshot = try await repository.refreshAll()
            apply(snapshot)
        } catch is CancellationError {
            // The pull-to-refresh gesture or view went away; nothing to report.
        } catch {
            if episodes.isEmpty {
                pageError = error.userMessage
            } else {
                refreshError = error.userMessage
            }
        }
    }

    // MARK: - Private

    private var isStale: Bool {
        guard let lastRefreshed else { return false }
        return now().timeIntervalSince(lastRefreshed) > staleInterval
    }

    private func apply(_ snapshot: EpisodeSnapshot) {
        listGeneration += 1
        episodes = snapshot.episodes
        lastRefreshed = snapshot.refreshedAt
        nextPage = nil
        pageError = nil
        refreshError = nil
        isLoadingPage = false
    }

    private func saveCompleteList() async {
        let snapshot = EpisodeSnapshot(episodes: episodes, refreshedAt: now())
        // Set before saving: the list on screen is fresh even if the disk is full.
        lastRefreshed = snapshot.refreshedAt
        // A failed save only means the list won't be available offline;
        // there's no need to bother the user with it.
        try? await repository.save(snapshot)
    }
}
