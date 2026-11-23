import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("App root")
struct AppRootTests {
    private func makeRoot(
        repository: any EpisodeRepository,
        schedule: @escaping @MainActor () -> Void
    ) -> AppRoot {
        AppRoot(
            repositories: .init(
                episodes: repository,
                characters: DefaultCharacterRepository.makeTemporary(api: StubAPI()),
                portraits: DefaultPortraitRepository.makeTemporary(api: StubAPI())
            ),
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString)).export,
            freshnessInterval: 3600,
            scheduleBackgroundRefresh: schedule
        )
    }

    /// The background task and the screens share one repository, as in the app; the task refreshes
    /// with `refreshFirstPage()`.
    private func makeRepository(initial: EpisodeSnapshot) async throws -> (DefaultEpisodeRepository, StubAPI) {
        let store = try await FileEpisodeStore.makeTemporary(containing: initial)
        let api = StubAPI(pages: [1: .success(.make(ids: 2...2, hasNextPage: false, totalCount: 1))])
        let repository = DefaultEpisodeRepository(
            api: api, store: store, now: { initial.refreshedAt.addingTimeInterval(60) }
        )
        return (repository, api)
    }

    @Test("Returning to the app shows a background refresh in the root's existing view model")
    func foregroundUpdatesOwnedViewModel() async throws {
        let initial = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: .now)
        let (repository, api) = try await makeRepository(initial: initial)
        var schedules = 0
        let root = makeRoot(repository: repository, schedule: { schedules += 1 })
        let viewModel = root.episodeListViewModel
        await viewModel.start()
        #expect(viewModel.episodes == initial.episodes)

        _ = try await repository.refreshFirstPage()
        await root.appBecameActive()

        #expect(root.episodeListViewModel === viewModel)
        #expect(viewModel.episodes.map(\.id) == [2])
        #expect(schedules == 0)
        // Only the background task's request: returning to the app reads the repository.
        #expect(await api.requestedPages == [1])
    }

    @Test("Entering the background schedules once and doesn't refresh the list")
    func backgroundSchedulesWithoutRefreshing() async throws {
        let initial = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: .now)
        let (repository, api) = try await makeRepository(initial: initial)
        var schedules = 0
        let root = makeRoot(repository: repository, schedule: { schedules += 1 })
        await root.episodeListViewModel.start()

        root.appEnteredBackground()

        #expect(schedules == 1)
        #expect(root.episodeListViewModel.episodes == initial.episodes)
        #expect(await api.requestedPages.isEmpty)

        _ = try await repository.refreshFirstPage()
        await root.appBecameActive()
        #expect(root.episodeListViewModel.episodes.map(\.id) == [2])
    }
}
