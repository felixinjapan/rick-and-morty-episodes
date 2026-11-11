import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list refresh indicator")
struct EpisodeListRefreshIndicatorTests {
    @Test("Cancelling one refresh keeps the other refresh visible")
    func overlappingRefreshIndicator() async {
        let api = threePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let repository = EpisodeRepository(api: api, store: RecordingStore())
        let model = EpisodeListModel(repository: repository)
        let first = Task { await model.refresh() }
        let second = Task { await model.refresh() }
        while await repository.refreshWaiterCount != 2 { await Task.yield() }
        first.cancel()
        await first.value

        #expect(model.isRefreshing)
        await gate.open()
        await second.value
        #expect(!model.isRefreshing)
        #expect(model.episodes.count == 45)
    }
}
