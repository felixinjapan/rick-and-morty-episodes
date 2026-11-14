import Foundation

/// Composition root: the one place where concrete implementations are chosen.
/// Everything below it receives its dependencies through initialisers.
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

    /// Exports go to Documents/Exports. Documents is exposed in the Files app
    /// (`UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`), so a file can be opened
    /// from Files › On My iPhone › Episodes, or handed to another app through the share sheet.
    static func makeExporter() -> CharacterExporter {
        CharacterExporter(directory: URL.documentsDirectory.appending(path: "Exports", directoryHint: .isDirectory))
    }

    private static func makeDataSources(
        configuration: AppConfiguration,
        arguments: [String]
    ) -> (any RickAndMortyAPI, FileEpisodeStore) {
        #if DEBUG
        // UI tests launch with `-uiTesting`: recorded API responses, so they're deterministic and
        // never touch the network. The real file store is used (in a separate folder whose name
        // contains a space, like "Application Support") so relaunching from the cache is tested
        // too; `-resetCache` starts from an empty cache.
        if arguments.contains("-uiTesting") {
            let cacheURL = URL.temporaryDirectory
                .appending(path: "UI Testing")
                .appending(path: FileEpisodeStore.defaultFileName)
            if arguments.contains("-resetCache") {
                try? FileManager.default.removeItem(at: cacheURL)
            }
            // `-networkUnavailable`: every request fails, so anything on screen came from the cache.
            let api: any RickAndMortyAPI = arguments.contains("-networkUnavailable")
                ? UnavailableRickAndMortyAPI()
                : RecordedRickAndMortyAPI()
            return (api, FileEpisodeStore(fileURL: cacheURL))
        }

        // `-offline`: the normal app on recorded responses, e.g. for a demo without Wi-Fi.
        if arguments.contains("-offline") {
            return (RecordedRickAndMortyAPI(), FileEpisodeStore.makeDefault())
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
