import Foundation

/// Composition root: the one place where concrete implementations are chosen.
/// Everything below it receives its dependencies through initialisers.
struct AppDependencies {
    let repository: EpisodeRepository

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppDependencies {
        #if DEBUG
        // UI tests launch with `-uiTesting` so they run against deterministic local data and
        // never touch the network. The real file store is used (in a separate folder whose name
        // contains a space, like "Application Support") so relaunching from the cache is tested
        // too; `-resetCache` starts from an empty cache.
        if arguments.contains("-uiTesting") {
            let cacheURL = URL.temporaryDirectory.appending(path: "UI Testing/episodes-cache.json")
            if arguments.contains("-resetCache") {
                try? FileManager.default.removeItem(at: cacheURL)
            }
            return AppDependencies(
                repository: EpisodeRepository(api: FixtureRickAndMortyAPI(), store: FileEpisodeStore(fileURL: cacheURL))
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
