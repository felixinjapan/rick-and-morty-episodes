import Foundation
import os
import Testing
@testable import RickAndMortyEpisodes

@Suite("Background refresh")
struct BackgroundRefreshTests {
    @Test("Scheduling uses the supplied interval")
    func schedulesWithInjectedInterval() {
        var submissions = 0
        BackgroundRefresh.schedule(minimumInterval: 90, now: fixedDate) { request in
            submissions += 1
            #expect(request.identifier == BackgroundRefresh.taskIdentifier)
            #expect(request.earliestBeginDate == fixedDate.addingTimeInterval(90))
        }
        #expect(submissions == 1)
    }

    @Test("Schedules the next run before refreshing, then saves page 1", .timeLimit(.minutes(1)))
    func schedulesFirstThenRefreshes() async throws {
        let api = makeThreePageAPI()
        let gate = Gate()
        await api.holdPage(1, until: gate)
        let store = FileEpisodeStore.makeTemporary()
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate })
        let scheduleCount = OSAllocatedUnfairLock(initialState: 0)

        let run = Task {
            await BackgroundRefresh.perform(using: repository, scheduleNext: { scheduleCount.withLock { $0 += 1 } })
        }
        while await api.requestedPages.isEmpty { await Task.yield() }

        // The page-1 request is held, so scheduling must already have happened.
        #expect(scheduleCount.withLock { $0 } == 1)
        await gate.open()
        await run.value
        #expect(try await store.load()?.episodes.count == 20)
    }

    @Test("Still schedules the next run when the refresh fails")
    func schedulesEvenWhenRefreshFails() async {
        let api = StubAPI(pages: [1: .failure(APIError.offline)])
        let repository = DefaultEpisodeRepository(api: api, store: .makeTemporary())
        let scheduleCount = OSAllocatedUnfairLock(initialState: 0)

        await BackgroundRefresh.perform(using: repository, scheduleNext: { scheduleCount.withLock { $0 += 1 } })

        #expect(scheduleCount.withLock { $0 } == 1)
    }
}
