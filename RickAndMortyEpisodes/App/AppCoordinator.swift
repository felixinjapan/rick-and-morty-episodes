import SwiftUI

@MainActor
final class AppCoordinator {
    let episodeListViewModel: EpisodeListViewModel

    private let characters: any CharacterRepository
    private let exporter: any CharacterExporting
    private let scheduleBackgroundRefresh: @MainActor () -> Void

    init(
        repositories: AppDependencies.Repositories,
        exporter: any CharacterExporting,
        freshnessInterval: TimeInterval,
        scheduleBackgroundRefresh: @escaping @MainActor () -> Void
    ) {
        episodeListViewModel = EpisodeListViewModel(
            repository: repositories.episodes,
            staleInterval: freshnessInterval
        )
        characters = repositories.characters
        self.exporter = exporter
        self.scheduleBackgroundRefresh = scheduleBackgroundRefresh
    }

    var rootView: some View {
        EpisodeListView(viewModel: episodeListViewModel, characterRepository: characters, exporter: exporter)
    }

    func handle(_ phase: ScenePhase) async {
        switch phase {
        case .active:
            await episodeListViewModel.refreshIfNeeded()
        case .background:
            scheduleBackgroundRefresh()
        default:
            break
        }
    }
}
