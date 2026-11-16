import SwiftUI

@main
struct RickAndMortyEpisodesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let repositories: AppDependencies.Repositories
    private let scheduleBackgroundRefresh: @Sendable () -> Void
    @State private var coordinator: AppCoordinator

    init() {
        let configuration = AppConfiguration.production
        let repositories = AppDependencies.makeRepositories(configuration: configuration)
        let scheduleBackgroundRefresh: @Sendable () -> Void = {
            BackgroundRefresh.schedule(minimumInterval: configuration.freshnessInterval)
        }
        self.repositories = repositories
        self.scheduleBackgroundRefresh = scheduleBackgroundRefresh
        _coordinator = State(initialValue: AppCoordinator(
            repositories: repositories,
            exporter: AppDependencies.makeExporter(),
            freshnessInterval: configuration.freshnessInterval,
            scheduleBackgroundRefresh: scheduleBackgroundRefresh
        ))
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task { await coordinator.handle(newPhase) }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) {
            [episodes = repositories.episodes, scheduleNext = scheduleBackgroundRefresh] in
            await BackgroundRefresh.perform(using: episodes, scheduleNext: scheduleNext)
        }
    }
}
