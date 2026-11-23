import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("App dependencies")
struct AppDependenciesTests {
    @Test("Saved character details are fetched again once an episode refresh finds a bigger catalogue")
    func characterDetailsFollowEpisodeCatalogue() async throws {
        let api = makeThreePageAPI()
        await api.setCharacter(1, .success(.rick))
        let repositories = AppDependencies.makeRepositories(
            api: api, cacheDirectory: .temporaryDirectory.appending(path: UUID().uuidString), characterMaxAge: 3600
        )
        _ = try await repositories.episodes.loadNextPage()
        _ = try await repositories.characters.character(id: 1)
        _ = try await repositories.characters.character(id: 1)
        #expect(await api.requestedCharacters == [1])

        await api.setPage(1, .success(.make(ids: 1...20, hasNextPage: true, totalCount: 46)))
        _ = try await repositories.episodes.refreshFirstPage()
        _ = try await repositories.characters.character(id: 1)

        #expect(await api.requestedCharacters == [1, 1])
    }
}
