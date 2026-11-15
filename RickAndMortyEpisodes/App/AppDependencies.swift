import Foundation

/// The composition root: the only place that chooses concrete implementations.
enum AppDependencies {
    struct Repositories {
        let episodes: any EpisodeRepository
        let characters: any CharacterRepository
    }

    /// Both repositories share one API client.
    static func makeRepositories(
        configuration: AppConfiguration = .current,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Repositories {
        let (api, store) = makeDataSources(configuration: configuration, arguments: arguments)
        return Repositories(
            episodes: DefaultEpisodeRepository(api: api, store: store),
            characters: DefaultCharacterRepository(api: api)
        )
    }

    /// Exports go to `Documents/Exports`, which the Files app shows (`UIFileSharingEnabled`,
    /// `LSSupportsOpeningDocumentsInPlace`); the share sheet can hand them to other apps.
    static func makeExporter() -> CharacterExporter {
        CharacterExporter(directory: URL.documentsDirectory.appending(path: "Exports", directoryHint: .isDirectory))
    }

    private static func makeDataSources(
        configuration: AppConfiguration,
        arguments: [String]
    ) -> (any RickAndMortyAPI, FileEpisodeStore) {
        #if DEBUG
        // `-uiTesting` uses stub data and a separate cache file, so UI tests never touch the network.
        // The cache folder's name contains a space, like "Application Support"; `-resetCache` empties it.
        if arguments.contains("-uiTesting") {
            let cacheURL = URL.temporaryDirectory
                .appending(path: "UI Testing")
                .appending(path: FileEpisodeStore.defaultFileName)
            if arguments.contains("-resetCache") {
                try? FileManager.default.removeItem(at: cacheURL)
            }
            // `-networkUnavailable` fails every request, so anything on screen came from the cache.
            let api: any RickAndMortyAPI = arguments.contains("-networkUnavailable")
                ? UnavailableRickAndMortyAPI()
                : RecordedRickAndMortyAPI()
            return (api, FileEpisodeStore(fileURL: cacheURL))
        }
        #endif

        let api = LiveRickAndMortyAPI(
            baseURL: configuration.apiBaseURL,
            transport: .urlSession(.api(
                requestTimeout: configuration.requestTimeout,
                resourceTimeout: configuration.resourceTimeout
            ))
        )
        return (api, FileEpisodeStore.makeDefault())
    }
}
