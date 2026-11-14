import BackgroundTasks
import os

/// Keeps the episode cache fresh while the app is in the background using a `BGAppRefreshTask`.
///
/// iOS decides when, and whether, the task runs, based on how the user uses the app,
/// battery and network. `earliestBeginDate` is only a lower bound. The foreground path
/// (refresh on launch/foreground when stale) is what guarantees reasonably fresh data;
/// this task is an optimisation on top of it.
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

    /// Runs when iOS launches the task. SwiftUI's `.backgroundTask` modifier cancels this
    /// async function when the system's time runs out. A request still in flight then fails
    /// and nothing is saved; a page that already arrived is still saved (one small atomic write).
    static func perform(using repository: any EpisodeRepository) async {
        // Schedule the next run first, so one failure doesn't stop future refreshes.
        schedule()
        do {
            let snapshot = try await repository.refreshFirstPage()
            logger.info("Background refresh saved \(snapshot.episodes.count) episodes")
        } catch {
            logger.error("Background refresh failed: \(String(describing: error), privacy: .public)")
        }
    }
}
