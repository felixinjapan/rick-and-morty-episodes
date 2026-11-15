import Foundation
import Observation

@MainActor
@Observable
final class CharacterDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded(CharacterDetails)
        case failed(message: String)
    }

    struct ExportedFile: Identifiable, Equatable {
        let url: URL
        var id: URL { url }
    }

    private(set) var state: State = .loading
    /// Set after a successful export; drives the confirmation sheet.
    var exportedFile: ExportedFile?
    /// Set when an export fails; drives the "Export Failed" alert, which resets it on dismissal.
    var exportErrorMessage: String?

    let characterID: Int
    private let repository: any CharacterRepository
    private let exporter: any CharacterExporting

    init(characterID: Int, repository: any CharacterRepository, exporter: any CharacterExporting) {
        self.characterID = characterID
        self.repository = repository
        self.exporter = exporter
    }

    var character: CharacterDetails? {
        if case .loaded(let character) = state { character } else { nil }
    }

    func load() async {
        // Keep a loaded character on screen while it reloads, so the list keeps its scroll position.
        if character == nil {
            state = .loading
        }
        do {
            state = .loaded(try await repository.character(id: characterID))
        } catch is CancellationError {
            // The user left the screen; `.task` will reload if it appears again.
        } catch {
            state = .failed(message: error.userMessage)
        }
    }

    func export() {
        guard let character else { return }
        do {
            // A few hundred bytes, so writing synchronously on the main actor is fine.
            exportedFile = ExportedFile(url: try exporter.export(character))
        } catch {
            exportErrorMessage = String(localized: .characterDetailExportFailedMessage(error.localizedDescription))
        }
    }
}
