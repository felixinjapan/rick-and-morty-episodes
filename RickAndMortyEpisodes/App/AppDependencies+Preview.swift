#if DEBUG
import Foundation

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
