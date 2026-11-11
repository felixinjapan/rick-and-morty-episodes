import SwiftUI

@main
struct RickAndMortyEpisodesApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let repository = AppDependencies.makeRepository()

    var body: some Scene {
        WindowGroup {
            EpisodeListView(repository: repository)
                // Explicit tint from the asset (light, dark and high-contrast variants), so the
                // accent never falls back to system blue if the Info.plist accent isn't applied.
                .tint(Color("AccentColor"))
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) { [repository] in
            await BackgroundRefresh.perform(using: repository)
        }
    }
}
