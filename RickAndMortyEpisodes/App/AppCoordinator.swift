import SwiftUI

@MainActor
final class AppCoordinator {
    let episodeListViewModel: EpisodeListViewModel

    private let screens: CharacterScreens
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
        screens = AppDependencies.makeCharacterScreens(characters: repositories.characters, exporter: exporter)
        self.scheduleBackgroundRefresh = scheduleBackgroundRefresh
    }

    var rootView: some View {
        EpisodeListView(viewModel: episodeListViewModel, screens: screens)
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
