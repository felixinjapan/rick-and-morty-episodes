#if DEBUG
extension AppDependencies {
    /// Dependencies for SwiftUI previews, so the views in Presentation don't pick Data types
    /// themselves. Recorded responses, or a network where every request fails, and a fresh
    /// cache each time.
    static func makePreviewRepositories(networkUnavailable: Bool = false) -> Repositories {
        let api: any RickAndMortyAPI = networkUnavailable ? UnavailableRickAndMortyAPI() : RecordedRickAndMortyAPI()
        return Repositories(
            episodes: DefaultEpisodeRepository(api: api, store: .preview()),
            characters: DefaultCharacterRepository(api: api)
        )
    }
}
#endif
