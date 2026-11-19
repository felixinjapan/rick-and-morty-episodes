import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode list grouping")
struct EpisodeListSeasonGroupTests {
    private func makeViewModel(
        api: StubAPI = makeThreePageAPI(), store: FileEpisodeStore = .makeTemporary()
    ) -> EpisodeListViewModel {
        let repository = DefaultEpisodeRepository(api: api, store: store, now: { fixedDate })
        return EpisodeListViewModel(repository: repository, staleInterval: 3600, now: { fixedDate })
    }

    private func episode(id: Int, code: String) -> Episode {
        Episode(id: id, name: "Episode \(id)", airDate: nil, code: code, characterIDs: [])
    }

    @Test("Seasons are sorted, episodes keep their order, and unrecognized codes come last")
    func groupsBySeason() async throws {
        let cached = EpisodeSnapshot(
            episodes: [
                episode(id: 1, code: "S02E01"), episode(id: 2, code: "Special"),
                episode(id: 3, code: "S01E02"), episode(id: 4, code: "S02E02"),
                episode(id: 5, code: "S01E01"),
            ],
            refreshedAt: fixedDate
        )
        let viewModel = makeViewModel(store: try await .makeTemporary(containing: cached))

        await viewModel.start()

        #expect(viewModel.seasonGroups.map(\.season) == [1, 2, nil])
        #expect(viewModel.seasonGroups.map { $0.episodes.map(\.id) } == [[3, 5], [1, 4], [2]])
        #expect(Set(viewModel.seasonGroups.map(\.id)).count == 3)
    }

    @Test("Groups follow the list as pages arrive")
    func groupsUpdateWithPages() async {
        let viewModel = makeViewModel()
        await viewModel.start()
        #expect(viewModel.seasonGroups.isEmpty)

        await viewModel.loadNextPage()
        #expect(viewModel.seasonGroups.map(\.season) == [1])
        #expect(viewModel.seasonGroups.first?.episodes.count == 20)

        await viewModel.loadNextPage()
        #expect(viewModel.seasonGroups.first?.episodes.count == 40)
    }

    @Test("The first-page spinner shows only while nothing is loaded yet")
    func firstPageSpinner() async {
        let viewModel = makeViewModel()
        #expect(viewModel.isLoadingFirstPage == false)

        await viewModel.start()
        #expect(viewModel.isLoadingFirstPage)

        await viewModel.loadNextPage()
        #expect(viewModel.isLoadingFirstPage == false)
    }

    @Test("A catalogue the API reports as empty ends the list at once, with no error")
    func emptyCatalogue() async {
        let api = StubAPI(pages: [1: .success(EpisodePage(episodes: [], hasNextPage: false, totalCount: 0))])
        let viewModel = makeViewModel(api: api)

        await viewModel.start()
        await viewModel.loadNextPage()

        #expect(viewModel.episodes.isEmpty)
        #expect(viewModel.seasonGroups.isEmpty)
        #expect(viewModel.emptyListErrorMessage == nil)
        #expect(viewModel.isLoadingFirstPage == false)
        #expect(viewModel.footer == .endReached(count: 0))
        #expect(await api.requestedPages == [1])
    }

    @Test("A refresh that returns an empty first page replaces the cached list without crashing")
    func refreshToEmptyCatalogue() async throws {
        let cached = EpisodeSnapshot(episodes: (1...3).map(Episode.make), refreshedAt: fixedDate)
        let api = StubAPI(pages: [1: .success(EpisodePage(episodes: [], hasNextPage: false, totalCount: 0))])
        let viewModel = makeViewModel(api: api, store: try await .makeTemporary(containing: cached))

        await viewModel.start()
        #expect(viewModel.episodes.count == 3)
        await viewModel.refresh()

        #expect(viewModel.episodes.isEmpty)
        #expect(viewModel.refreshErrorMessage == nil)
        #expect(viewModel.footer == .endReached(count: 0))
    }

    @Test("The first-page spinner gives way to the error when the first page fails")
    func firstPageSpinnerStopsOnFailure() async {
        let api = StubAPI(pages: [1: .failure(APIError.offline)])
        let viewModel = makeViewModel(api: api)

        await viewModel.start()
        await viewModel.loadNextPage()

        #expect(viewModel.isLoadingFirstPage == false)
        #expect(viewModel.emptyListErrorMessage == RepositoryError.offline.userMessage)
    }
}
