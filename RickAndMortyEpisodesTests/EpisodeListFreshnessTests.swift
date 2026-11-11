import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list freshness")
struct EpisodeListFreshnessTests {
    @Test("A cache write failure does not disable future foreground refreshes")
    func failedBootstrapSaveStillTracksFreshness() async {
        let api = threePageAPI()
        let repository = EpisodeRepository(api: api, store: FailingSaveStore(), now: { fixedDate })
        var currentDate = fixedDate
        let model = EpisodeListModel(repository: repository, now: { currentDate })
        await model.start()
        for _ in 0..<3 { await model.loadNextPage() }
        #expect(model.episodes.count == 45)
        #expect(model.lastRefreshed == fixedDate)

        currentDate = fixedDate.addingTimeInterval(7200)
        await model.appDidBecomeActive()
        #expect(await api.requestedPages.filter { $0 == 1 }.count == 2)
    }
}

private actor FailingSaveStore: EpisodeStore {
    func load() -> EpisodeSnapshot? { nil }
    func save(_ snapshot: EpisodeSnapshot) throws { throw CocoaError(.fileWriteOutOfSpace) }
}
