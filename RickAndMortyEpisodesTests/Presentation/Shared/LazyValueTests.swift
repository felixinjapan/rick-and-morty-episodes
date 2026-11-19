import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Lazy value")
struct LazyValueTests {
    @Test("Nothing is built until the value is read, and it is built once")
    func buildsOnceOnFirstUse() {
        var builds = 0
        let lazy = LazyValue { () -> Int in
            builds += 1
            return builds
        }
        #expect(builds == 0)

        #expect(lazy.value == 1)
        #expect(lazy.value == 1)
        #expect(builds == 1)
    }
}
