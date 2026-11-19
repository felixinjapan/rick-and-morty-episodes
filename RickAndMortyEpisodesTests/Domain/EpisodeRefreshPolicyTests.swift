import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Episode refresh policy")
struct EpisodeRefreshPolicyTests {
    private let policy = EpisodeRefreshPolicy(staleInterval: 3600)
    private let refreshedAt = Date(timeIntervalSince1970: 1_000_000)

    @Test("A list is stale only after the interval has passed", arguments: [
        (0.0, false), (3599, false), (3600, false), (3601, true),
    ])
    func age(elapsed: TimeInterval, expected: Bool) {
        #expect(
            policy.isStale(refreshedAt: refreshedAt, now: refreshedAt.addingTimeInterval(elapsed)) == expected
        )
    }

    @Test("A list that was never refreshed has no age to check")
    func neverRefreshed() {
        #expect(!policy.isStale(refreshedAt: nil, now: refreshedAt))
    }
}
