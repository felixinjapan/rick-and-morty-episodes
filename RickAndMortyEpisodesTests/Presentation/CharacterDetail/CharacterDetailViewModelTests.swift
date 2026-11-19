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
        let repository = DefaultCharacterRepository.makeTemporary(api: StubAPI(characters: [1: .success(.rick)]))
        let viewModel = CharacterDetailViewModel(
            portraitLoader: PortraitLoader(repository: repository), exporter: CharacterExporter(directory: directory)
        ) {
            try await repository.character(id: 1)
        }

        await viewModel.load()
        #expect(viewModel.state == .loaded(.rick))

        viewModel.export()
        let file = try #require(viewModel.exportedFile)
        #expect(FileManager.default.fileExists(atPath: file.url.path(percentEncoded: false)))
    }

    @Test("A failed load shows an error and export stays unavailable")
    func loadFailure() async {
        let repository = DefaultCharacterRepository.makeTemporary(api: StubAPI())
        let viewModel = CharacterDetailViewModel(
            portraitLoader: PortraitLoader(repository: repository),
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString))
        ) {
            try await repository.character(id: 99999)
        }

        await viewModel.load()
        viewModel.export()

        #expect(viewModel.state == .failed(message: RepositoryError.notFound.userMessage))
        #expect(viewModel.exportedFile == nil)
    }

    @Test("An invalid portrait shows a fallback while keeping the character details")
    func invalidPortrait() async throws {
        let url = try #require(CharacterDetails.rick.imageURL)
        let repository = DefaultCharacterRepository.makeTemporary(api: StubAPI(portraits: [url: .success(Data([0]))]))
        let viewModel = CharacterDetailViewModel(
            character: .rick, portraitLoader: PortraitLoader(repository: repository),
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString))
        ) {
            Issue.record("Loaded details should never be resolved again")
            throw RepositoryError.notFound
        }

        guard case .loading = viewModel.portraitPhase else {
            Issue.record("Expected the portrait to start in the loading state")
            return
        }
        await viewModel.loadPortrait()

        #expect(viewModel.state == .loaded(.rick))
        guard case .failed = viewModel.portraitPhase else {
            Issue.record("Expected the portrait to fall back after invalid image data")
            return
        }
    }

    @Test("A failed load can be retried and then shows the character")
    func retryAfterFailure() async {
        let api = StubAPI()
        let repository = DefaultCharacterRepository.makeTemporary(api: api)
        let viewModel = CharacterDetailViewModel(
            portraitLoader: PortraitLoader(repository: repository),
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString))
        ) {
            try await repository.character(id: 1)
        }

        await viewModel.load()
        #expect(viewModel.state == .failed(message: RepositoryError.notFound.userMessage))

        await api.setCharacter(1, .success(.rick))
        await viewModel.load()
        #expect(viewModel.state == .loaded(.rick))
    }

    @Test("A downloaded portrait is shown at the detail size")
    func portraitLoads() async throws {
        let url = try #require(CharacterDetails.rick.imageURL)
        let repository = DefaultCharacterRepository.makeTemporary(
            api: StubAPI(portraits: [url: .success(RecordedResponses.portrait)])
        )
        let viewModel = CharacterDetailViewModel(
            character: .rick, portraitLoader: PortraitLoader(repository: repository),
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString))
        ) {
            throw RepositoryError.notFound
        }

        await viewModel.loadPortrait()

        guard case .loaded = viewModel.portraitPhase else {
            Issue.record("Expected the downloaded portrait to be shown")
            return
        }
    }

    @Test("Passed details are ready to export without resolving the character again")
    func exportFailure() async throws {
        let blocker = try makeTemporaryBlockingFile()
        defer { try? FileManager.default.removeItem(at: blocker) }
        let viewModel = CharacterDetailViewModel(
            character: .rick,
            portraitLoader: PortraitLoader(repository: DefaultCharacterRepository.makeTemporary(api: StubAPI())),
            exporter: CharacterExporter(directory: blocker.appending(path: "Exports"))
        ) {
            Issue.record("Loaded details should never be resolved again")
            throw RepositoryError.notFound
        }

        #expect(viewModel.state == .loaded(.rick))
        await viewModel.load()
        viewModel.export()

        #expect(viewModel.exportErrorMessage == String(localized: .characterDetailExportFailedMessage))
        #expect(viewModel.exportedFile == nil)
    }
}
