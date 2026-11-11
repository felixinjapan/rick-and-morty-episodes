import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list refresh indicator")
struct EpisodeListRefreshIndicatorTests {
    @Test("The indicator stays visible until every overlapping refresh finishes")
    func overlappingRefreshIndicator() async {
        let api = threePageAPI()
        let slowGate = Gate()
        await api.holdPage(1, until: slowGate)
        let repository = EpisodeRepository(api: api, store: RecordingStore())
        let model = EpisodeListModel(repository: repository)

        let slow = Task { await model.refresh() }
        while await api.requestedPages.isEmpty { await Task.yield() }

        // The second refresh isn't held, so it finishes while the first is still running.
        let openGate = Gate()
        await openGate.open()
        await api.holdPage(1, until: openGate)
        await model.refresh()
        #expect(model.isRefreshing)

        await slowGate.open()
        await slow.value
        #expect(!model.isRefreshing)
        #expect(model.episodes.count == 45)
    }
}
