import Foundation

/// The composition root: the only place that chooses concrete implementations.
enum AppDependencies {
    struct Repositories {
        let episodes: any EpisodeRepository
        let characters: any CharacterRepository
    }

    /// Both repositories share one API client. The character repository asks the episode repository
    /// how big the catalogue is, to tell whether saved character details are out of date.
    static func makeRepositories(
        configuration: AppConfiguration = .current,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Repositories {
        let sources = makeDataSources(configuration: configuration, arguments: arguments)
        let episodes = DefaultEpisodeRepository(api: sources.api, store: sources.episodeStore)
        return Repositories(
            episodes: episodes,
            characters: DefaultCharacterRepository(
                api: sources.api,
                store: sources.characterStore,
                catalogueCount: { await episodes.loadCurrentSnapshot()?.totalCount },
                maxAge: configuration.characterMaxAge
            )
        )
    }

    /// Exports go to `Documents/Exports`, which the Files app shows (`UIFileSharingEnabled`,
    /// `LSSupportsOpeningDocumentsInPlace`); the share sheet can hand them to other apps.
    static func makeExporter() -> CharacterExporter {
        CharacterExporter(directory: URL.documentsDirectory.appending(path: "Exports", directoryHint: .isDirectory))
    }

    private struct DataSources {
        let api: any RickAndMortyAPI
        let episodeStore: FileEpisodeStore
        let characterStore: FileCharacterStore
    }

    private static func makeDataSources(
        configuration: AppConfiguration,
        arguments: [String]
    ) -> DataSources {
        #if DEBUG
        // `-uiTesting` uses stub data and a separate cache file, so UI tests never touch the network.
        // The cache folder's name contains a space, like "Application Support"; `-resetCache` empties it.
        if arguments.contains("-uiTesting") {
            let folder = URL.temporaryDirectory.appending(path: "UI Testing")
            let cacheURL = folder.appending(path: FileEpisodeStore.defaultFileName)
            let charactersURL = folder.appending(path: "characters", directoryHint: .isDirectory)
            if arguments.contains("-resetCache") {
                try? FileManager.default.removeItem(at: cacheURL)
                try? FileManager.default.removeItem(at: charactersURL)
            }
            // `-networkUnavailable` fails every request, so anything on screen came from the cache.
            let api: any RickAndMortyAPI = arguments.contains("-networkUnavailable")
                ? UnavailableRickAndMortyAPI()
                : RecordedRickAndMortyAPI()
            return DataSources(
                api: api, episodeStore: FileEpisodeStore(fileURL: cacheURL),
                characterStore: FileCharacterStore(directory: charactersURL)
            )
        }
        #endif

        let api = LiveRickAndMortyAPI(
            baseURL: configuration.apiBaseURL,
            transport: .urlSession(.api(
                requestTimeout: configuration.requestTimeout,
                resourceTimeout: configuration.resourceTimeout
            ))
        )
        return DataSources(api: api, episodeStore: .makeDefault(), characterStore: .makeDefault())
    }
}
