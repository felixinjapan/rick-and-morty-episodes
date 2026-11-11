import Foundation

/// Composition root: the one place where concrete implementations are chosen.
/// Everything below it receives its dependencies through initialisers.
struct AppDependencies {
    let repository: EpisodeRepository

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppDependencies {
        #if DEBUG
        // UI tests launch with `-uiTesting` so they run against deterministic local data:
        // no network, no state left over from earlier runs.
        if arguments.contains("-uiTesting") {
            return AppDependencies(
                repository: EpisodeRepository(api: FixtureRickAndMortyAPI(), store: InMemoryEpisodeStore())
            )
        }
        #endif

        return AppDependencies(
            repository: EpisodeRepository(
                api: LiveRickAndMortyAPI(transport: .urlSession(.api)),
                store: FileEpisodeStore.makeDefault()
            )
        )
    }
}
