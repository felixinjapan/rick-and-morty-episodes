import SwiftUI

@main
struct RickAndMortyEpisodesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let repositories: AppDependencies.Repositories
    @State private var coordinator: AppCoordinator

    init() {
        let repositories = AppDependencies.makeRepositories()
        self.repositories = repositories
        _coordinator = State(initialValue: AppCoordinator(
            repositories: repositories,
            exporter: AppDependencies.makeExporter(),
            freshnessInterval: AppConfiguration.current.freshnessInterval
        ))
    }

    var body: some Scene {
        WindowGroup {
            coordinator.rootView
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task { await coordinator.handle(newPhase) }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) { [episodes = repositories.episodes] in
            await BackgroundRefresh.perform(using: episodes)
        }
    }
}
