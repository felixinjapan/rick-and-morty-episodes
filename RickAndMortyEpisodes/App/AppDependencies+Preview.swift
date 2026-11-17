#if DEBUG
import Foundation

extension AppDependencies {
    /// Dependencies for SwiftUI previews, so Presentation doesn't pick Data types itself: stub data,
    /// or a network where every request fails, and a fresh cache each time.
    static func makePreviewRepositories(
        configuration: AppConfiguration,
        networkUnavailable: Bool = false
    ) -> Repositories {
        let api: any RickAndMortyAPI = networkUnavailable ? UnavailableRickAndMortyAPI() : RecordedRickAndMortyAPI()
        let store = SwiftDataStore.makeInMemory()
        let episodes = DefaultEpisodeRepository(api: api, store: store)
        return Repositories(
            episodes: episodes,
            characters: DefaultCharacterRepository(
                api: api,
                store: store,
                portraits: .makePreview(),
                catalogueCount: { await episodes.loadCurrentSnapshot()?.totalCount },
                maxAge: configuration.characterMaxAge
            )
        )
    }

    /// Exports from previews go to a temporary folder.
    static func makePreviewExporter() -> CharacterExporter {
        CharacterExporter(directory: .temporaryDirectory.appending(path: "Previews/Exports"))
    }
}
#endif
