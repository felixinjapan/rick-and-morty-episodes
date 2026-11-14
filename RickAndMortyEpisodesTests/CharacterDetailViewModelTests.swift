import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Character detail view model")
struct CharacterDetailViewModelTests {
    @Test("Loads the character, then exports it")
    func loadAndExport() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = DefaultCharacterRepository(api: StubAPI(characters: [1: .success(.rick)]))
        let viewModel = CharacterDetailViewModel(
            characterID: 1, repository: repository, exporter: CharacterExporter(directory: directory)
        )

        await viewModel.load()
        #expect(viewModel.state == .loaded(.rick))

        viewModel.export()
        let file = try #require(viewModel.exportedFile)
        #expect(FileManager.default.fileExists(atPath: file.url.path(percentEncoded: false)))
    }

    @Test("A failed load shows an error and export stays unavailable")
    func loadFailure() async {
        let repository = DefaultCharacterRepository(api: StubAPI())
        let viewModel = CharacterDetailViewModel(characterID: 99999, repository: repository)

        await viewModel.load()
        viewModel.export()

        #expect(viewModel.state == .failed(message: EpisodeError.notFound.userMessage))
        #expect(viewModel.exportedFile == nil)
    }
}
