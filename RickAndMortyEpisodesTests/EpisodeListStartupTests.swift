import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list startup")
struct EpisodeListStartupTests {
    @Test("An initial cache read cannot undo a completed refresh", arguments: [false, true])
    func startCannotReplaceCompletedRefresh(hasCache: Bool) async {
        let previous = hasCache ? EpisodeSnapshot(episodes: [.make(id: 999)], refreshedAt: fixedDate) : nil
        let store = GatedInitialLoadStore(snapshot: previous)
        let repository = EpisodeRepository(api: threePageAPI(), store: store, now: { fixedDate })
        let model = EpisodeListModel(repository: repository, now: { fixedDate })
        let start = Task { await model.start() }
        await store.loadStarted.wait()
        await model.refresh()
        #expect(model.episodes.count == 45)
        await store.releaseLoad.open()
        await start.value

        #expect(model.episodes.map(\.id) == Array(1...45))
        #expect(model.footer == .endReached(count: 45))
    }
}

/// Captures the first cache read before letting a concurrent refresh replace it.
private actor GatedInitialLoadStore: EpisodeStore {
    let loadStarted = Gate()
    let releaseLoad = Gate()
    private var snapshot: EpisodeSnapshot?
    private var hasRead = false

    init(snapshot: EpisodeSnapshot?) { self.snapshot = snapshot }

    func load() async -> EpisodeSnapshot? {
        guard !hasRead else { return snapshot }
        hasRead = true
        let captured = snapshot
        await loadStarted.open()
        await releaseLoad.wait()
        return captured
    }

    func save(_ snapshot: EpisodeSnapshot) { self.snapshot = snapshot }
}
