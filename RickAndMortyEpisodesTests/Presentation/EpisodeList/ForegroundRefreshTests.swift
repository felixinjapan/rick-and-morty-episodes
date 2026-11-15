import Foundation
import Testing
@testable import RickAndMortyEpisodes

/// A repository whose cache read and refresh can be held, to control how two calls interleave.
private actor GatedRepository: EpisodeRepository {
    private(set) var refreshCalls = 0
    private(set) var readsWaiting = 0
    private var readGate: Gate?
    private var refreshGate: Gate?
    private let snapshot: EpisodeSnapshot

    init(snapshot: EpisodeSnapshot) { self.snapshot = snapshot }

    func hold(reads: Gate?, refreshes: Gate?) {
        readGate = reads
        refreshGate = refreshes
    }

    func loadCurrentSnapshot() async -> EpisodeSnapshot? {
        if let gate = readGate {
            readsWaiting += 1
            await gate.wait()
        }
        return snapshot
    }

    func loadNextPage(after current: EpisodeSnapshot?) async throws -> EpisodeSnapshot { snapshot }

    func refreshFirstPage() async throws -> EpisodeSnapshot {
        refreshCalls += 1
        if let gate = refreshGate { await gate.wait() }
        return EpisodeSnapshot(episodes: snapshot.episodes, refreshedAt: fixedDate.addingTimeInterval(50_000))
    }
}

@MainActor
@Suite("Foreground checks")
struct ForegroundRefreshTests {
    @Test("Two overlapping checks that both read the cache start only one refresh", .timeLimit(.minutes(1)))
    func overlappingChecksStartOneRefresh() async {
        let repository = GatedRepository(snapshot: EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: fixedDate))
        var clock = fixedDate.addingTimeInterval(7200)
        let viewModel = EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { clock })
        await viewModel.start()                       // stale at launch: one refresh runs and finishes
        let callsAfterLaunch = await repository.refreshCalls
        clock = fixedDate.addingTimeInterval(100_000)  // stale again

        let readGate = Gate()
        let refreshGate = Gate()
        await repository.hold(reads: readGate, refreshes: refreshGate)
        let first = Task { await viewModel.refreshIfNeeded() }
        let second = Task { await viewModel.refreshIfNeeded() }
        // Both passed the "is a refresh running?" guard and are waiting on the cache read.
        while await repository.readsWaiting < 2 { await Task.yield() }
        await readGate.open()
        while await repository.refreshCalls == callsAfterLaunch { await Task.yield() }
        for _ in 0..<50 { await Task.yield() }          // let the second check reach a refresh, if it will
        let whileFirstRuns = await repository.refreshCalls - callsAfterLaunch
        await refreshGate.open()
        await first.value
        await second.value

        #expect(whileFirstRuns == 1, "refresh calls while the first was still running: \(whileFirstRuns)")
    }
}
