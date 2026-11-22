import Foundation

enum AppDependencies {
    struct Repositories {
        let episodes: any EpisodeRepository
        let characters: any CharacterRepository
        let portraits: any PortraitRepository
    }

    static func makeRepositories(
        configuration: AppConfiguration,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Repositories {
        #if DEBUG
        if let uiTesting = UITestEnvironment(arguments: arguments) {
            return makeRepositories(
                api: uiTesting.api, cacheDirectory: uiTesting.cacheDirectory,
                characterMaxAge: configuration.characterMaxAge
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
                catalogue: episodes,
                policy: CharacterCachePolicy(maxAge: characterMaxAge)
            ),
            portraits: DefaultPortraitRepository(
                api: api,
                store: PortraitStore(directory: cacheDirectory.appending(path: "portraits", directoryHint: .isDirectory))
            )
        )
    }

    /// The share sheet asks for the file when the user picks a destination (Save to Files, AirDrop,
    /// another app), so it only has to exist briefly; the temporary folder is cleared by the system.
    static func makeExporter() -> CharacterExporter {
        CharacterExporter(directory: URL.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory))
    }
}
