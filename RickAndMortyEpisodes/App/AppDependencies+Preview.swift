#if DEBUG
import Foundation

enum PreviewData {
    static let character = CharacterDetails(
        id: 1, name: "Rick Sanchez", status: .alive, species: "Human",
        originName: "Earth (C-137)", episodeCount: 51,
        imageURL: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")
    )

    static let episode = Episode(
        id: 1, name: "Pilot", airDate: Date(timeIntervalSince1970: 1_385_942_400),
        code: "S01E01", characterIDs: [1, 2, 35]
    )
}

extension AppDependencies {
    static func makePreviewRepositories(
        configuration: AppConfiguration,
        networkUnavailable: Bool = false
    ) -> Repositories {
        let api: any RickAndMortyAPI = networkUnavailable ? UnavailableRickAndMortyAPI() : LiveRickAndMortyAPI.recorded()
        return makeRepositories(
            api: api,
            cacheDirectory: .temporaryDirectory.appending(path: "Previews/\(UUID().uuidString)"),
            characterMaxAge: configuration.characterMaxAge
        )
    }

    @MainActor
    static func makePreviewScreens(networkUnavailable: Bool = false) -> CharacterScreens {
        let repositories = makePreviewRepositories(
            configuration: .production, networkUnavailable: networkUnavailable
        )
        return makeCharacterScreens(
            characters: repositories.characters, portraits: repositories.portraits, exporter: makePreviewExporter().export
        )
    }

    static func makePreviewPortraitLoader() -> LoadThumbnail {
        PortraitLoader(repository: makePreviewRepositories(configuration: .production).portraits).loadThumbnail
    }

    static func makePreviewExporter() -> CharacterExporter {
        CharacterExporter(directory: .temporaryDirectory.appending(path: "Previews/Exports"))
    }
}
#endif
