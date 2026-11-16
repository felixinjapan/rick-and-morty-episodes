import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("App coordinator")
struct AppCoordinatorTests {
    private func makeCoordinator(
        repository: any EpisodeRepository,
        schedule: @escaping @MainActor () -> Void
    ) -> AppCoordinator {
        AppCoordinator(
            repositories: .init(
                episodes: repository,
                characters: DefaultCharacterRepository.makeTemporary(api: StubAPI())
            ),
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString)),
            freshnessInterval: 3600,
            scheduleBackgroundRefresh: schedule
        )
    }

    @Test("Foreground events update the coordinator's existing view model from the cache")
    func foregroundUpdatesOwnedViewModel() async throws {
        let initial = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: .now)
        let store = try await FileEpisodeStore.makeTemporary(containing: initial)
        let api = StubAPI()
        let repository = DefaultEpisodeRepository(api: api, store: store)
        var schedules = 0
        let coordinator = makeCoordinator(repository: repository, schedule: { schedules += 1 })
        let viewModel = coordinator.episodeListViewModel
        await viewModel.start()
        #expect(viewModel.episodes == initial.episodes)

        let newer = EpisodeSnapshot(episodes: [.make(id: 2)], refreshedAt: initial.refreshedAt.addingTimeInterval(60))
        try await store.save(newer)
        await coordinator.handle(.active)

        #expect(coordinator.episodeListViewModel === viewModel)
        #expect(viewModel.episodes == newer.episodes)
        #expect(schedules == 0)
        #expect(await api.requestedPages.isEmpty)
    }

    @Test("Background schedules once and inactive does nothing; neither refreshes the list")
    func backgroundAndInactive() async throws {
        let initial = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: .now)
        let store = try await FileEpisodeStore.makeTemporary(containing: initial)
        let api = StubAPI()
        let repository = DefaultEpisodeRepository(api: api, store: store)
        var schedules = 0
        let coordinator = makeCoordinator(repository: repository, schedule: { schedules += 1 })
        await coordinator.episodeListViewModel.start()
        try await store.save(EpisodeSnapshot(
            episodes: [.make(id: 2)], refreshedAt: initial.refreshedAt.addingTimeInterval(60)
        ))

        await coordinator.handle(.inactive)
        #expect(schedules == 0)
        await coordinator.handle(.background)

        #expect(schedules == 1)
        #expect(coordinator.episodeListViewModel.episodes == initial.episodes)
        #expect(await api.requestedPages.isEmpty)

        await coordinator.handle(.active)
        #expect(coordinator.episodeListViewModel.episodes.map(\.id) == [2])
    }
}
