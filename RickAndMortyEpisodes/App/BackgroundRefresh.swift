import BackgroundTasks
import os

/// Refreshes the episode cache in the background with a `BGAppRefreshTask`.
///
/// iOS decides when, and whether, the task runs; `earliestBeginDate` is only a lower bound.
/// The foreground refresh of stale data is what keeps the list fresh; this is an extra.
enum BackgroundRefresh {
    /// Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let taskIdentifier = "dev.felixinjapan.RickAndMortyEpisodes.refresh"
    static let minimumInterval = AppConfiguration.current.freshnessInterval

    private static let logger = Logger(category: "BackgroundRefresh")

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumInterval)
        do {
            // Submitting again replaces the pending request for this identifier.
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Expected in the Simulator and when Background App Refresh is turned off.
            logger.notice("Background refresh not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Runs when iOS launches the task; SwiftUI cancels it when time runs out. A request still in
    /// flight then fails and saves nothing, but a page that already arrived is saved.
    /// `scheduleNext` is injectable so tests don't need `BGTaskScheduler`.
    static func perform(
        using repository: any EpisodeRepository,
        scheduleNext: () -> Void = { BackgroundRefresh.schedule() }
    ) async {
        // Schedule the next run first, so one failure doesn't stop future refreshes.
        scheduleNext()
        do {
            let snapshot = try await repository.refreshFirstPage()
            logger.info("Background refresh fetched \(snapshot.episodes.count) episodes")
        } catch is CancellationError {
            // The system's time ran out: expected, not a failure.
            logger.info("Background refresh cancelled")
        } catch {
            logger.error("Background refresh failed: \(String(describing: error), privacy: .public)")
        }
    }
}
