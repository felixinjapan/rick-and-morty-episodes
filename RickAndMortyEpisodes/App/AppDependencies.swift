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
                catalogueCount: { await episodes.loadCurrentSnapshot()?.totalCount },
                policy: CharacterCachePolicy(maxAge: characterMaxAge)
            ),
            portraits: DefaultPortraitRepository(
                api: api,
                store: PortraitStore(directory: cacheDirectory.appending(path: "portraits", directoryHint: .isDirectory))
            )
        )
    }

    @MainActor
    static func makeCharacterScreens(
        characters: any CharacterRepository, portraits: any PortraitRepository,
        exporter: @escaping ExportCharacter
    ) -> CharacterScreens {
        let thumbnails = PortraitLoader(repository: portraits).loadThumbnail
        // The detail portrait is 200 points, or 600 pixels on a 3x display.
        let detailPortraits = PortraitLoader(repository: portraits, maxPixelSize: 600).loadThumbnail
        return CharacterScreens(
            makeCast: { episode in
                EpisodeCharactersViewModel(
                    characterIDs: episode.characterIDs, repository: characters, loadThumbnail: thumbnails
                )
            },
            makeDetail: { route, resolveCharacter in
                CharacterDetailViewModel(
                    character: route.character, loadThumbnail: detailPortraits, exporter: exporter,
                    resolveCharacter: resolveCharacter
                )
            }
        )
    }

    /// The share sheet asks for the file when the user picks a destination (Save to Files, AirDrop,
    /// another app), so it only has to exist briefly; the temporary folder is cleared by the system.
    static func makeExporter() -> CharacterExporter {
        CharacterExporter(directory: URL.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory))
    }
}
