import SwiftUI

@main
struct RickAndMortyEpisodesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let dependencies = AppDependencies.make()

    var body: some Scene {
        WindowGroup {
            EpisodeListView(repository: dependencies.repository)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) { [repository = dependencies.repository] in
            await BackgroundRefresh.perform(using: repository)
        }
    }
}
