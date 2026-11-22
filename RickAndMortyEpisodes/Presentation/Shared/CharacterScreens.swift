@MainActor
struct CharacterScreens {
    let makeCast: (Episode) -> EpisodeCharactersViewModel
    /// `resolveCharacter` loads the character when the route doesn't carry its details.
    let makeDetail: (CharacterRoute, _ resolveCharacter: @escaping () async throws -> CharacterDetails)
        -> CharacterDetailViewModel
}

extension CharacterScreens {
    /// The character screens wire their own view models, so the app root only passes repositories in.
    init(
        characters: any CharacterRepository, portraits: any PortraitRepository,
        exporter: @escaping ExportCharacter
    ) {
        let thumbnails = PortraitLoader(repository: portraits).loadThumbnail
        // The detail portrait is 200 points, or 600 pixels on a 3x display.
        let detailPortraits = PortraitLoader(repository: portraits, maxPixelSize: 600).loadThumbnail
        self.init(
            makeCast: { episode in
                EpisodeCharactersViewModel(
                    characterIDs: episode.characterIDs, repository: characters, loadThumbnail: thumbnails
                )
            },
            makeDetail: { route, resolveCharacter in
                CharacterDetailViewModel(
                    character: route.character, loadThumbnail: detailPortraits, exporter: exporter,
                    resolveCharacter: resolveCharacter
                )
            }
        )
    }
}
