import Foundation

/// Navigation stays in the views' `NavigationStack`, because every route is a push from one screen.
/// The app entry point turns scene phases into the calls below, so the root doesn't depend on SwiftUI.
@MainActor
final class AppRoot {
    let episodeListViewModel: EpisodeListViewModel
    let characterScreens: CharacterScreens

    private let scheduleBackgroundRefresh: @MainActor () -> Void

    init(
        repositories: AppDependencies.Repositories,
        exporter: @escaping ExportCharacter,
        freshnessInterval: TimeInterval,
        scheduleBackgroundRefresh: @escaping @MainActor () -> Void
    ) {
        episodeListViewModel = EpisodeListViewModel(
            repository: repositories.episodes,
            refreshPolicy: EpisodeRefreshPolicy(staleInterval: freshnessInterval)
        )
        characterScreens = CharacterScreens(
            characters: repositories.characters, portraits: repositories.portraits, exporter: exporter
        )
        self.scheduleBackgroundRefresh = scheduleBackgroundRefresh
    }

    func appBecameActive() async {
        await episodeListViewModel.refreshIfNeeded()
    }

    func appEnteredBackground() {
        scheduleBackgroundRefresh()
    }
}
