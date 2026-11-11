import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list paging cancellation")
struct EpisodeListPagingCancellationTests {
    @Test("Cancelling the final page's footer does not discard the completed cache")
    func cancelledFinalPageStillPersists() async {
        let api = threePageAPI()
        let gate = Gate()
        await api.holdPage(3, until: gate)
        let store = RecordingStore()
        let repository = EpisodeRepository(api: api, store: store, now: { fixedDate })
        let model = EpisodeListModel(repository: repository, now: { fixedDate })
        await model.start()
        await model.loadNextPage()
        await model.loadNextPage()
        let finalPage = Task { await model.loadNextPage() }
        while !(await api.requestedPages.contains(3)) { await Task.yield() }
        finalPage.cancel()
        await gate.open()
        await finalPage.value

        #expect(model.episodes.count == 45)
        #expect(await store.snapshot?.episodes.count == 45)
        #expect(model.lastRefreshed == fixedDate)
    }
}
