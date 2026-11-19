import Foundation

struct EpisodeRefreshPolicy: Sendable {
    let staleInterval: TimeInterval

    /// A list that was never refreshed has no age, so it isn't stale.
    func isStale(refreshedAt: Date?, now: Date) -> Bool {
        guard let refreshedAt else { return false }
        return now.timeIntervalSince(refreshedAt) > staleInterval
    }
}
