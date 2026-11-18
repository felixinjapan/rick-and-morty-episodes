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
            let cast: DelayedEpisodeFeed.Cast = if arguments.contains("-characterEdgeCases") {
                .edgeCases
            } else if arguments.contains("-endlessCharacters") {
                .endless
            } else {
                .recorded
            }
            let directory = URL.temporaryDirectory.appending(path: delayedFeed ? cast.rawValue : "UI Testing")
            if arguments.contains("-resetCache") {
                try? FileManager.default.removeItem(at: directory)
            }
            let api: any RickAndMortyAPI = if arguments.contains("-networkUnavailable") {
                UnavailableRickAndMortyAPI()
            } else if delayedFeed {
                DelayedEpisodeFeed(cast: cast)
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

    @MainActor
    static func makeCharacterScreens(
        characters: any CharacterRepository, exporter: any CharacterExporting
    ) -> CharacterScreens {
        let thumbnails = PortraitLoader(repository: characters)
        // The detail portrait is 200 points, or 600 pixels on a 3x display.
        let detailPortraits = PortraitLoader(repository: characters, maxPixelSize: 600)
        return CharacterScreens(
            makeCast: { episode in
                EpisodeCharactersViewModel(
                    characterIDs: episode.characterIDs, repository: characters, portraitLoader: thumbnails
                )
            },
            makeDetail: { route, resolveCharacter in
                CharacterDetailViewModel(
                    character: route.character, portraitLoader: detailPortraits, exporter: exporter,
                    resolveCharacter: resolveCharacter
                )
            }
        )
    }

    /// Exports go to `Documents/Exports`, which the Files app shows (`UIFileSharingEnabled`,
    /// `LSSupportsOpeningDocumentsInPlace`); the share sheet can hand them to other apps.
    static func makeExporter() -> CharacterExporter {
        CharacterExporter(directory: URL.documentsDirectory.appending(path: "Exports", directoryHint: .isDirectory))
    }
}
