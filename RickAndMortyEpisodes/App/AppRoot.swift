import SwiftUI

/// Owns the root screen's state for the app's lifetime and turns scene-phase changes into refreshes.
/// Navigation stays in the views' `NavigationStack`, because every route is a push from one screen.
@MainActor
final class AppRoot {
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
        screens = AppDependencies.makeCharacterScreens(
            characters: repositories.characters, portraits: repositories.portraits, exporter: exporter
        )
        self.scheduleBackgroundRefresh = scheduleBackgroundRefresh
    }

    var content: some View {
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
