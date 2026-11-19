import Foundation

/// When the episode list is old enough to check again on launch or when returning to the app.
struct EpisodeRefreshPolicy: Sendable {
    let staleInterval: TimeInterval

    /// A list that was never refreshed has no age, so it isn't stale.
    func isStale(refreshedAt: Date?, now: Date) -> Bool {
        guard let refreshedAt else { return false }
        return now.timeIntervalSince(refreshedAt) > staleInterval
    }
}
