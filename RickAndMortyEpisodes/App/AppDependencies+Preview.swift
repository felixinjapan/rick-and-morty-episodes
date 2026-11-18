#if DEBUG
import Foundation

enum PreviewData {
    static let character = CharacterDetails(
        id: 1, name: "Rick Sanchez", status: .alive, species: "Human",
        originName: "Earth (C-137)", episodeCount: 51,
        imageURL: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")
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

    static func makePreviewExporter() -> CharacterExporter {
        CharacterExporter(directory: .temporaryDirectory.appending(path: "Previews/Exports"))
    }
}
#endif
