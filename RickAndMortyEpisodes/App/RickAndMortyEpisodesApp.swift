import SwiftUI

@main
struct RickAndMortyEpisodesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let repository: any EpisodeRepository
    /// Owned here rather than by the view, so the app's lifecycle handler can reach it.
    @State private var episodeList: EpisodeListViewModel

    init() {
        let repository = AppDependencies.makeRepository()
        self.repository = repository
        _episodeList = State(initialValue: EpisodeListViewModel(
            repository: repository,
            staleInterval: AppConfiguration.current.freshnessInterval
        ))
    }

    var body: some Scene {
        WindowGroup {
            EpisodeListView(viewModel: episodeList, repository: repository)
                // Explicit tint from the asset (light, dark and high-contrast variants), so the
                // accent never falls back to system blue if the Info.plist accent isn't applied.
                .tint(Color("AccentColor"))
        }
        .onChange(of: scenePhase) { _, newPhase in
            // The app's whole lifecycle handling in one place.
            switch newPhase {
            case .active:
                // Picks up data a background refresh saved, and refreshes if it's stale.
                Task { await episodeList.refreshIfNeeded() }
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) { [repository] in
            await BackgroundRefresh.perform(using: repository)
        }
    }
}
