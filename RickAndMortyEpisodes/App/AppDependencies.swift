import Foundation

enum AppDependencies {
    struct Repositories {
        let episodes: any EpisodeRepository
        let characters: any CharacterRepository
    }

    static func makeRepositories(
        configuration: AppConfiguration,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Repositories {
        #if DEBUG
        // UI tests use recorded data and a separate cache.
        if arguments.contains("-uiTesting") {
            let delayedFeed = arguments.contains("-delayedEpisodeFeed")
            let directory = URL.temporaryDirectory.appending(path: delayedFeed ? "Delayed Episode Feed" : "UI Testing")
            if arguments.contains("-resetCache") {
                try? FileManager.default.removeItem(at: directory)
            }
            let api: any RickAndMortyAPI = if arguments.contains("-networkUnavailable") {
                UnavailableRickAndMortyAPI()
            } else if delayedFeed {
                DelayedEpisodeFeed()
            } else {
                LiveRickAndMortyAPI.recorded()
            }
            return makeRepositories(api: api, cacheDirectory: directory, characterMaxAge: configuration.characterMaxAge)
        }
        #endif

        let api = LiveRickAndMortyAPI(
            baseURL: configuration.apiBaseURL,
            transport: .urlSession(.api(
                requestTimeout: configuration.requestTimeout,
                resourceTimeout: configuration.resourceTimeout
            ))
        )
        // Application Support keeps downloaded episodes, details and portraits available offline.
        return makeRepositories(
            api: api, cacheDirectory: .applicationSupportDirectory, characterMaxAge: configuration.characterMaxAge
        )
    }

    static func makeRepositories(
        api: any RickAndMortyAPI, cacheDirectory: URL, characterMaxAge: TimeInterval
    ) -> Repositories {
        let episodes = DefaultEpisodeRepository(
            api: api, store: FileEpisodeStore(fileURL: cacheDirectory.appending(path: FileEpisodeStore.defaultFileName))
        )
        return Repositories(
            episodes: episodes,
            characters: DefaultCharacterRepository(
                api: api,
                store: FileCharacterStore(directory: cacheDirectory.appending(path: "characters", directoryHint: .isDirectory)),
                portraits: PortraitStore(directory: cacheDirectory.appending(path: "portraits", directoryHint: .isDirectory)),
                catalogueCount: { await episodes.loadCurrentSnapshot()?.totalCount },
                maxAge: characterMaxAge
            )
        )
    }

    /// Exports go to `Documents/Exports`, which the Files app shows (`UIFileSharingEnabled`,
    /// `LSSupportsOpeningDocumentsInPlace`); the share sheet can hand them to other apps.
    static func makeExporter() -> CharacterExporter {
        CharacterExporter(directory: URL.documentsDirectory.appending(path: "Exports", directoryHint: .isDirectory))
    }
}
