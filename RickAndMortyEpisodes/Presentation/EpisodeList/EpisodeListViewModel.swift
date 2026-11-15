import Foundation
import Observation

/// State of the episode list: paging, cached content, pull-to-refresh and "last updated".
/// Main-actor isolated because SwiftUI reads it; that also makes the "is a page already loading?"
/// check-and-set atomic, so duplicate page requests can't happen.
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

    /// The list as the repository last returned it; `nil` until the cache or page 1 arrives.
    private var snapshot: EpisodeSnapshot?
    var episodes: [Episode] { snapshot?.episodes ?? [] }
    /// When page 1 was last fetched.
    var lastRefreshedAt: Date? { snapshot?.refreshedAt }
    var isRefreshing: Bool { activeRefreshCount > 0 }
    /// Shown as a banner when a refresh fails but older content is still on screen.
    private(set) var refreshErrorMessage: String?
    /// Changes when returning to the app replaced loaded rows with a shorter list. The view uses it
    /// as the list's `.id`, so SwiftUI rebuilds the list from the top instead of landing mid-list.
    /// Page loads and pull-to-refresh don't change it.
    private(set) var listIdentity = 0

    private var pageErrorMessage: String?
    private var isLoadingPage = false
    private var hasStarted = false
    private var hasCheckedCache = false
    private var activeRefreshCount = 0
    /// Incremented whenever the whole list is replaced. A page request that started earlier ignores
    /// its outcome: its error or "finished" belongs to the old list.
    private var listGeneration = 0

    private let repository: any EpisodeRepository
    private let staleInterval: TimeInterval
    private let now: () -> Date

    init(
        repository: any EpisodeRepository,
        staleInterval: TimeInterval,
        now: @escaping () -> Date = { .now }
    ) {
        self.repository = repository
        self.staleInterval = staleInterval
        self.now = now
    }

    /// A load error while no episodes are on screen; the view shows it full screen.
    var emptyListErrorMessage: String? {
        episodes.isEmpty ? pageErrorMessage : nil
    }

    /// The page to load next: page 1 when there is no list yet, `nil` once it is complete.
    private var nextPage: Int? {
        snapshot == nil ? 1 : snapshot?.nextPage
    }

    var footer: Footer {
        guard hasCheckedCache, emptyListErrorMessage == nil else { return .none }
        if let pageErrorMessage { return .failed(message: pageErrorMessage) }
        if let nextPage { return .loading(page: nextPage) }
        return .endReached(count: episodes.count)
    }

    // MARK: - Lifecycle

    /// Shows the cached list at once, then refreshes it if stale. Without a cache, the footer's
    /// `.loading(page: 1)` starts the paging.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        if let snapshot = await repository.loadCurrentSnapshot() {
            apply(snapshot)
        }
        hasCheckedCache = true

        if isStale {
            await refresh()
        }
    }

    /// Applies a newer snapshot (for example from the background task), then refreshes if the data
    /// is still stale. The app calls this when it becomes active.
    func refreshIfNeeded() async {
        // A running refresh (e.g. at launch) will update the list; another would repeat its request.
        guard hasCheckedCache, !isRefreshing else { return }
        let rowsBefore = episodes.count
        if let snapshot = await repository.loadCurrentSnapshot(),
           snapshot.refreshedAt > (lastRefreshedAt ?? .distantPast) {
            apply(snapshot)
        }
        if isStale {
            await refresh()
        }
        if episodes.count < rowsBefore {
            listIdentity += 1
        }
    }

    // MARK: - Paging

    func loadNextPage() async {
        guard !isLoadingPage, nextPage != nil else { return }
        isLoadingPage = true
        pageErrorMessage = nil
        let generation = listGeneration
        let current = snapshot
        let repository = self.repository

        // Its own task, so scrolling the footer away (which cancels the view's `.task`) doesn't
        // cancel the request. The result belongs to the view model, not the view.
        let result = await Task { try await repository.loadNextPage(after: current) }.result

        guard generation == listGeneration else { return }
        isLoadingPage = false

        switch result {
        case .success(let list):
            // The repository appended the page and saved the list.
            apply(list)
        case .failure(let error):
            // A cancelled request is not a failure: show nothing; the page loads again on the next trigger.
            guard !(error is CancellationError) else { return }
            pageErrorMessage = error.userMessage
        }
    }

    // MARK: - Refresh

    /// Restarts the list from a fresh page 1; deeper pages load again on scroll. Used by
    /// pull-to-refresh and for stale data.
    func refresh() async {
        activeRefreshCount += 1
        defer { activeRefreshCount -= 1 }

        do {
            let snapshot = try await repository.refreshFirstPage()
            apply(snapshot)
        } catch is CancellationError {
            // The gesture or view went away; nothing to report.
        } catch {
            if episodes.isEmpty {
                pageErrorMessage = error.userMessage
            } else {
                refreshErrorMessage = error.userMessage
            }
        }
    }

    // MARK: - Private

    private var isStale: Bool {
        guard let lastRefreshedAt else { return false }
        return now().timeIntervalSince(lastRefreshedAt) > staleInterval
    }

    private func apply(_ snapshot: EpisodeSnapshot) {
        // Only a new fetch of page 1 makes the data fresh; a page added to the same list doesn't,
        // so a refresh error stays until then.
        if snapshot.refreshedAt != lastRefreshedAt {
            refreshErrorMessage = nil
        }
        listGeneration += 1
        self.snapshot = snapshot
        pageErrorMessage = nil
        isLoadingPage = false
    }
}
