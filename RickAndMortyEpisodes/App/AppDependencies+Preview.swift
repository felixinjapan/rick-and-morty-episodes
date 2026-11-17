#if DEBUG
import Foundation

extension AppDependencies {
    static func makePreviewRepositories(
        configuration: AppConfiguration,
        networkUnavailable: Bool = false
    ) -> Repositories {
        let api: any RickAndMortyAPI = networkUnavailable ? UnavailableRickAndMortyAPI() : LiveRickAndMortyAPI.recorded()
        let episodes = DefaultEpisodeRepository(api: api, store: .makePreview())
        return Repositories(
            episodes: episodes,
            characters: DefaultCharacterRepository(
                api: api,
                store: .makePreview(),
                portraits: .makePreview(),
                catalogueCount: { await episodes.loadCurrentSnapshot()?.totalCount },
                maxAge: configuration.characterMaxAge
            )
        )
    }

    static func makePreviewExporter() -> CharacterExporter {
        CharacterExporter(directory: .temporaryDirectory.appending(path: "Previews/Exports"))
    }
}
#endif
