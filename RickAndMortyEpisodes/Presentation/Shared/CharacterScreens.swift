@MainActor
struct CharacterScreens {
    let makeCast: (Episode) -> EpisodeCharactersViewModel
    /// `resolveCharacter` loads the character when the route doesn't carry its details.
    let makeDetail: (CharacterRoute, _ resolveCharacter: @escaping () async throws -> CharacterDetails)
        -> CharacterDetailViewModel
}
