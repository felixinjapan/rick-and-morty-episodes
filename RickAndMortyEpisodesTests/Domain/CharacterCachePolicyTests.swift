import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Character cache policy")
struct CharacterCachePolicyTests {
    private let policy = CharacterCachePolicy(maxAge: 3600)
    private let savedAt = Date(timeIntervalSince1970: 1_000_000)

    @Test("Details are fresh until they reach the maximum age", arguments: [
        (0.0, true), (3599, true), (3600, false), (7200, false),
    ])
    func age(elapsed: TimeInterval, expected: Bool) {
        #expect(
            policy.isFresh(
                savedAt: savedAt, savedCatalogueCount: 45, currentCatalogueCount: 45,
                now: savedAt.addingTimeInterval(elapsed)
            ) == expected
        )
    }

    @Test("A different catalogue size makes details stale at any age", arguments: [(45, 46), (46, 45)])
    func catalogueChanged(saved: Int, current: Int) {
        #expect(
            !policy.isFresh(savedAt: savedAt, savedCatalogueCount: saved, currentCatalogueCount: current, now: savedAt)
        )
    }

    @Test("An unknown catalogue size on either side never counts as a change", arguments: [
        (Int?.none, Int?.some(46)), (45, nil), (nil, nil),
    ])
    func unknownCatalogue(saved: Int?, current: Int?) {
        #expect(
            policy.isFresh(savedAt: savedAt, savedCatalogueCount: saved, currentCatalogueCount: current, now: savedAt)
        )
    }
}
