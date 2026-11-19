import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Character detail view model")
struct CharacterDetailViewModelTests {
    @Test("Loads the character, then offers an export file that is written only when asked for")
    func loadAndExport() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let api = StubAPI(characters: [1: .success(.rick)])
        let repository = DefaultCharacterRepository.makeTemporary(api: api)
        let viewModel = CharacterDetailViewModel(
            loadThumbnail: PortraitLoader(repository: DefaultPortraitRepository.makeTemporary(api: api)).loadThumbnail,
            exporter: CharacterExporter(directory: directory).export
        ) {
            try await repository.character(id: 1)
        }

        await viewModel.load()
        #expect(viewModel.state == .loaded(.rick))

        let file = try #require(viewModel.exportFile)
        #expect(!FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))

        let url = try file.write()
        #expect(url.lastPathComponent == "Character-1-Rick-Sanchez.txt")
        #expect(try String(contentsOf: url, encoding: .utf8) == CharacterExporter.text(for: .rick))
    }

    @Test("A failed load shows an error and export stays unavailable")
    func loadFailure() async {
        let api = StubAPI()
        let repository = DefaultCharacterRepository.makeTemporary(api: api)
        let viewModel = CharacterDetailViewModel(
            loadThumbnail: PortraitLoader(repository: DefaultPortraitRepository.makeTemporary(api: api)).loadThumbnail,
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString)).export
        ) {
            try await repository.character(id: 99999)
        }

        await viewModel.load()

        #expect(viewModel.state == .failed(message: RepositoryError.notFound.userMessage))
        #expect(viewModel.exportFile == nil)
    }

    @Test("An invalid portrait shows a fallback while keeping the character details")
    func invalidPortrait() async throws {
        let url = try #require(CharacterDetails.rick.imageURL)
        let repository = DefaultPortraitRepository.makeTemporary(api: StubAPI(portraits: [url: .success(Data([0]))]))
        let viewModel = CharacterDetailViewModel(
            character: .rick, loadThumbnail: PortraitLoader(repository: repository).loadThumbnail,
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString)).export
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
            loadThumbnail: PortraitLoader(repository: DefaultPortraitRepository.makeTemporary(api: api)).loadThumbnail,
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString)).export
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
        let repository = DefaultPortraitRepository.makeTemporary(
            api: StubAPI(portraits: [url: .success(RecordedResponses.portrait)])
        )
        let viewModel = CharacterDetailViewModel(
            character: .rick, loadThumbnail: PortraitLoader(repository: repository).loadThumbnail,
            exporter: CharacterExporter(directory: .temporaryDirectory.appending(path: UUID().uuidString)).export
        ) {
            throw RepositoryError.notFound
        }

        await viewModel.loadPortrait()

        guard case .loaded = viewModel.portraitPhase else {
            Issue.record("Expected the downloaded portrait to be shown")
            return
        }
    }

    @Test("Passed details are ready to export without resolving the character again, and a failed write throws")
    func exportFailure() async throws {
        let blocker = try makeTemporaryBlockingFile()
        defer { try? FileManager.default.removeItem(at: blocker) }
        let viewModel = CharacterDetailViewModel(
            character: .rick,
            loadThumbnail: PortraitLoader(repository: DefaultPortraitRepository.makeTemporary(api: StubAPI())).loadThumbnail,
            exporter: CharacterExporter(directory: blocker.appending(path: "Exports")).export
        ) {
            Issue.record("Loaded details should never be resolved again")
            throw RepositoryError.notFound
        }

        #expect(viewModel.state == .loaded(.rick))
        await viewModel.load()

        let file = try #require(viewModel.exportFile)
        #expect(throws: (any Error).self) { try file.write() }
    }
}
