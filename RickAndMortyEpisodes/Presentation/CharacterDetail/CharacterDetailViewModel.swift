import CoreGraphics
import Foundation
import Observation
import os

@MainActor
@Observable
final class CharacterDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(CharacterDetails)
        case failed(message: String)
    }

    private(set) var state: State = .loading
    private var portrait: (url: URL, phase: CharacterPortraitPhase)?

    private let logger = Logger(category: "CharacterDetailViewModel")
    private let exportCharacter: ExportCharacter
    private let loadThumbnail: LoadThumbnail
    private let resolveCharacter: () async throws -> CharacterDetails

    init(
        character: CharacterDetails? = nil, loadThumbnail: @escaping LoadThumbnail,
        exporter: @escaping ExportCharacter,
        resolveCharacter: @escaping () async throws -> CharacterDetails
    ) {
        state = character.map(State.loaded) ?? .loading
        self.loadThumbnail = loadThumbnail
        exportCharacter = exporter
        self.resolveCharacter = resolveCharacter
    }

    var character: CharacterDetails? {
        if case .loaded(let character) = state { character } else { nil }
    }

    var portraitPhase: CharacterPortraitPhase {
        guard let url = character?.imageURL else { return .failed }
        guard let portrait, portrait.url == url else { return .loading }
        return portrait.phase
    }

    func load() async {
        guard character == nil else { return }
        state = .loading
        do {
            state = .loaded(try await resolveCharacter())
        } catch is CancellationError {
            // The user left the screen; `.task` will reload if it appears again.
        } catch {
            state = .failed(message: error.userMessage)
        }
    }

    func loadPortrait() async {
        guard let character, let url = character.imageURL else { return }
        if case .loaded = portraitPhase { return }
        portrait = (url, .loading)
        // `nil` means the load was cancelled; `.task` starts it again if the screen reappears.
        guard let result = await loadThumbnail(character), !Task.isCancelled else { return }
        switch result {
        case .image(let image): portrait = (url, .loaded(image))
        case .unavailable: portrait = (url, .failed)
        }
    }

    /// What the share sheet offers for the loaded character; `nil` until there is one.
    var exportFile: CharacterExportFile? {
        guard let character else { return nil }
        let exportCharacter = exportCharacter
        let logger = logger
        return CharacterExportFile(title: character.name) {
            do {
                return try exportCharacter(character)
            } catch {
                logger.error("Export failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
    }
}
