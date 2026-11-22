import Testing
@testable import RickAndMortyEpisodes

@Suite("Cast chunk planner")
struct CastChunkPlannerTests {
    @Test("The first chunk holds 20 rows, then every chunk holds 80")
    func chunkBoundaries() {
        let planner = CastChunkPlanner(characterIDs: Array(1...300))

        #expect(planner.chunk(at: 0) == 0..<20)
        #expect(planner.chunk(at: 19) == 0..<20)
        #expect(planner.chunk(at: 20) == 20..<100)
        #expect(planner.chunk(at: 99) == 20..<100)
        #expect(planner.chunk(at: 100) == 100..<180)
    }

    @Test("The last chunk stops at the end of the cast")
    func lastChunkIsClipped() {
        let planner = CastChunkPlanner(characterIDs: Array(1...130))

        #expect(planner.chunk(at: 120) == 100..<130)
        #expect(CastChunkPlanner(characterIDs: Array(1...15)).chunk(at: 0) == 0..<15)
    }

    @Test("The first chunk always brings the second")
    func firstChunkBringsSecond() {
        let plan = CastChunkPlanner(characterIDs: Array(1...300)).chunks(for: [1, 2, 3])

        #expect(plan.held == [0..<20])
        #expect(plan.prefetch == [20..<100])
    }

    @Test("A short cast has nothing to prefetch")
    func shortCast() {
        let plan = CastChunkPlanner(characterIDs: Array(1...15)).chunks(for: [14, 15])

        #expect(plan.held == [0..<15])
        #expect(plan.prefetch.isEmpty)
    }

    @Test("The next chunk is requested once a row is 80% through its chunk, not before")
    func prefetchThreshold() {
        let planner = CastChunkPlanner(characterIDs: Array(1...400))

        #expect(planner.chunks(for: [84]).prefetch.isEmpty)
        #expect(planner.chunks(for: [85]).prefetch == [100..<180])
    }

    @Test("A far jump holds only the chunk around the destination")
    func farJump() {
        let plan = CastChunkPlanner(characterIDs: Array(1...10_000)).chunks(for: [5_001, 5_002])

        #expect(plan.held == [4_980..<5_060])
        #expect(plan.prefetch.isEmpty)
    }

    @Test("Rows in two chunks hold both, and a shared next chunk is listed once")
    func rowsInTwoChunks() {
        let plan = CastChunkPlanner(characterIDs: Array(1...400)).chunks(for: [19, 21, 99])

        #expect(plan.held == [0..<20, 20..<100])
        #expect(plan.prefetch == [100..<180])
    }

    @Test("IDs that are not in the cast, or no visible rows, plan nothing")
    func nothingToPlan() {
        let planner = CastChunkPlanner(characterIDs: Array(1...50))

        #expect(planner.chunks(for: []).held.isEmpty)
        #expect(planner.chunks(for: [999]).held.isEmpty)
        #expect(planner.chunks(for: [999]).prefetch.isEmpty)
    }

    @Test("Nearby IDs reach two rows past the visible ones, within the cast")
    func nearbyIDs() {
        let planner = CastChunkPlanner(characterIDs: Array(1...10))

        #expect(planner.nearbyIDs(for: [5], padding: 2) == [3, 4, 5, 6, 7])
        #expect(planner.nearbyIDs(for: [1], padding: 2) == [1, 2, 3])
        #expect(planner.nearbyIDs(for: [10], padding: 2) == [8, 9, 10])
        #expect(planner.nearbyIDs(for: [999], padding: 2) == [999])
    }

    @Test("A chunk's IDs follow the cast's order")
    func idsInChunk() {
        let planner = CastChunkPlanner(characterIDs: [7, 3, 9, 1])

        #expect(Array(planner.ids(in: 1..<3)) == [3, 9])
    }
}
