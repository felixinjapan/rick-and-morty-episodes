import Foundation

/// Composition root: the one place where concrete implementations are chosen.
/// Everything below it receives its dependencies through initialisers.
enum AppDependencies {
    static func makeRepository(
        configuration: AppConfiguration = .current,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> any EpisodeRepository {
        #if DEBUG
        // UI tests launch with `-uiTesting`: recorded API responses, so they're deterministic and
        // never touch the network. The real file store is used (in a separate folder whose name
        // contains a space, like "Application Support") so relaunching from the cache is tested
        // too; `-resetCache` starts from an empty cache.
        if arguments.contains("-uiTesting") {
            let cacheURL = URL.temporaryDirectory.appending(path: "UI Testing").appending(path: FileEpisodeStore.defaultFileName)
            if arguments.contains("-resetCache") {
                try? FileManager.default.removeItem(at: cacheURL)
            }
            // `-networkUnavailable`: every request fails, so anything on screen came from the cache.
            let api: any RickAndMortyAPI = arguments.contains("-networkUnavailable")
                ? UnavailableRickAndMortyAPI()
                : RecordedRickAndMortyAPI()
            return DefaultEpisodeRepository(api: api, store: FileEpisodeStore(fileURL: cacheURL))
        }

        // `-offline`: the normal app on recorded responses, e.g. for a demo without Wi-Fi.
        if arguments.contains("-offline") {
            return DefaultEpisodeRepository(api: RecordedRickAndMortyAPI(), store: FileEpisodeStore.makeDefault())
        }
        #endif

        return DefaultEpisodeRepository(
            api: LiveRickAndMortyAPI(
                baseURL: configuration.apiBaseURL,
                transport: .urlSession(.api(
                    requestTimeout: configuration.requestTimeout,
                    resourceTimeout: configuration.resourceTimeout
                ))
            ),
            store: FileEpisodeStore.makeDefault()
        )
    }
}
