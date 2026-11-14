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
    /// Drives the "Export Failed" alert; the alert sets it back to `false` when dismissed.
    var isShowingExportError = false
    private(set) var exportErrorMessage = ""

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
        // Keep a loaded character on screen while it reloads: going back to `.loading` would
        // tear down the list, and its scroll position, for data that is already there.
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
            isShowingExportError = true
        }
    }
}
