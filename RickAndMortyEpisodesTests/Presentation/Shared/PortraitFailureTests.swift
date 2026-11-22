import Testing
@testable import RickAndMortyEpisodes

@Suite("Portrait failure")
struct PortraitFailureTests {
    @Test("Each error maps to one way of handling it", arguments: [
        (RepositoryError.timedOut, PortraitFailure.transient(delay: .milliseconds(500))),
        (.serverUnavailable, .transient(delay: .milliseconds(500))),
        (.rateLimited, .transient(delay: .seconds(2))),
        (.offline, .retryLater),
        (.failed, .retryLater),
        (.notFound, .permanent),
        (.unreadableData, .permanent),
    ])
    func handling(error: RepositoryError, expected: PortraitFailure) {
        #expect(PortraitFailure(error) == expected)
    }
}
