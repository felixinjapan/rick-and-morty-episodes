/// Builds the view models for the character screens, so views never see repositories or the
/// exporter. `AppRoot` supplies the real dependencies.
@MainActor
struct CharacterScreens {
    let makeCast: (Episode) -> EpisodeCharactersViewModel
    /// `resolveCharacter` loads the character when the route doesn't carry its details.
    let makeDetail: (CharacterRoute, _ resolveCharacter: @escaping () async throws -> CharacterDetails)
        -> CharacterDetailViewModel
}
