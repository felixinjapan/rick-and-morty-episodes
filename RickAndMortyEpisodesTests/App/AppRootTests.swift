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

    @Test("Foreground events update the root's existing view model from the cache")
    func foregroundUpdatesOwnedViewModel() async throws {
        let initial = EpisodeSnapshot(episodes: [.make(id: 1)], refreshedAt: .now)
        let store = try await FileEpisodeStore.makeTemporary(containing: initial)
        let api = StubAPI()
        let repository = DefaultEpisodeRepository(api: api, store: store)
        var schedules = 0
        let root = makeRoot(repository: repository, schedule: { schedules += 1 })
        let viewModel = root.episodeListViewModel
        await viewModel.start()
        #expect(viewModel.episodes == initial.episodes)

        let newer = EpisodeSnapshot(episodes: [.make(id: 2)], refreshedAt: initial.refreshedAt.addingTimeInterval(60))
        try await store.save(newer)
        await root.handle(.active)

        #expect(root.episodeListViewModel === viewModel)
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
        let root = makeRoot(repository: repository, schedule: { schedules += 1 })
        await root.episodeListViewModel.start()
        try await store.save(EpisodeSnapshot(
            episodes: [.make(id: 2)], refreshedAt: initial.refreshedAt.addingTimeInterval(60)
        ))

        await root.handle(.inactive)
        #expect(schedules == 0)
        await root.handle(.background)

        #expect(schedules == 1)
        #expect(root.episodeListViewModel.episodes == initial.episodes)
        #expect(await api.requestedPages.isEmpty)

        await root.handle(.active)
        #expect(root.episodeListViewModel.episodes.map(\.id) == [2])
    }
}
