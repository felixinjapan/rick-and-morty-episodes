import SwiftUI

@main
struct RickAndMortyEpisodesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let repositories: AppDependencies.Repositories
    private let scheduleBackgroundRefresh: @Sendable () -> Void
    @State private var root: AppRoot

    init() {
        let configuration = AppConfiguration.production
        let repositories = AppDependencies.makeRepositories(configuration: configuration)
        let scheduleBackgroundRefresh: @Sendable () -> Void = {
            BackgroundRefresh.schedule(minimumInterval: configuration.freshnessInterval)
        }
        self.repositories = repositories
        self.scheduleBackgroundRefresh = scheduleBackgroundRefresh
        _root = State(initialValue: AppRoot(
            repositories: repositories,
            exporter: AppDependencies.makeExporter().export,
            freshnessInterval: configuration.freshnessInterval,
            scheduleBackgroundRefresh: scheduleBackgroundRefresh
        ))
    }

    var body: some Scene {
        WindowGroup {
            EpisodeListView(viewModel: root.episodeListViewModel, screens: root.characterScreens)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: Task { await root.appBecameActive() }
            case .background: root.appEnteredBackground()
            default: break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) {
            [episodes = repositories.episodes, scheduleNext = scheduleBackgroundRefresh] in
            await BackgroundRefresh.perform(using: episodes, scheduleNext: scheduleNext)
        }
    }
}
