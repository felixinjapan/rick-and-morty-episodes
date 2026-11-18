import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode character loading")
struct EpisodeCharactersViewModelTests {
    @Test("Portraits retry temporary server errors once and keep a placeholder for a missing image")
    func portraitFailures() async throws {
        let url = try #require(URL(string: "https://example.com/portrait.png"))
        let recovering = CharacterBatchRecorder(portraitURL: url, firstPortraitError: .serverUnavailable)
        let missing = CharacterBatchRecorder(portraitURL: url, firstPortraitError: .notFound)
        let recoveringModel = makeViewModel(repository: recovering)
        let missingModel = makeViewModel(repository: missing)

        await recoveringModel.loadVisibleCast(visibleIDs: [1])
        await missingModel.loadVisibleCast(visibleIDs: [1])
        await missingModel.loadVisibleCast(visibleIDs: [1])

        #expect(await recovering.portraitRequests == [url, url])
        #expect(await missing.portraitRequests == [url])
        guard case .loaded = recoveringModel.portraits.phase(for: url),
              case .failed = missingModel.portraits.phase(for: url) else {
            Issue.record("Expected the temporary failure to recover and the missing portrait to stay unavailable")
            return
        }
    }

    @Test("Recreated rows can reuse the same portrait from the cast cache")
    func reusesCachedPortrait() async throws {
        let url = try #require(URL(string: "https://example.com/portrait.png"))
        let otherURL = try #require(URL(string: "https://example.com/replacement.png"))
        let repository = CharacterBatchRecorder(portraitURL: url)
        let viewModel = makeViewModel(characterIDs: [1, 2], repository: repository)

        await viewModel.loadVisibleCast(visibleIDs: [1, 2])
        await viewModel.loadVisibleCast(visibleIDs: [])
        await viewModel.loadVisibleCast(visibleIDs: [1])

        #expect(await repository.portraitRequests == [url])
        guard case .loaded = viewModel.portraits.phase(for: url),
              case .loading = viewModel.portraits.phase(for: otherURL) else {
            Issue.record("Expected the loaded portrait to stay available by URL")
            return
        }
    }

    @Test("Cast IDs keep their original order and discard duplicates and invalid IDs")
    func normalizesCastIDs() {
        let episode = Episode(id: 1, name: "Episode", airDate: nil, code: "", characterIDs: [3, 0, 1, -1, 3, 2, 1])
        #expect(episode.characterIDs == [3, 1, 2])
    }

    @Test("Widely separated viewports prefetch bounded windows and skip the rows between them")
    func distantViewports() async {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(characterIDs: Array(1...10_000), repository: repository)
        let windows = stride(from: 1, through: 9_998, by: 909).map { Array($0...($0 + 2)) }

        await viewModel.loadVisibleCast(visibleIDs: [])
        for window in windows {
            await viewModel.loadVisibleCast(visibleIDs: Set(window))
        }
        await viewModel.loadVisibleCast(visibleIDs: Set(windows[0]))

        let expected = windows.map { window in
            Array(max(1, window[0] - 6)...min(10_000, window[2] + 6))
        }
        #expect(await repository.requests == expected)
        #expect(Set(viewModel.characters.keys) == Set(expected.joined()))
    }

    @Test("Opening a character from the cast reuses loaded details and saves a fallback lookup")
    func opensCharacterFromCast() async throws {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(characterIDs: Array(1...30), repository: repository)
        await viewModel.loadVisibleCast(visibleIDs: [4])

        #expect(try await viewModel.character(id: 8).id == 8)
        #expect(await repository.singleRequests.isEmpty)
        #expect(try await viewModel.character(id: 30).id == 30)
        #expect(try await viewModel.character(id: 30).id == 30)
        #expect(await repository.singleRequests == [30])
    }

    @Test("A fling skips intermediate rows and revisiting loaded rows makes no request")
    func skipsIntermediateRows() async throws {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadVisibleCast(visibleIDs: [1, 2])

        let passingRows = Task { await viewModel.loadVisibleCast(visibleIDs: [20, 21]) }
        try await Task.sleep(for: .milliseconds(35))
        #expect(viewModel.settledIDs == [1, 2])
        passingRows.cancel()
        await passingRows.value

        await viewModel.loadVisibleCast(visibleIDs: [59, 60])
        #expect(viewModel.settledIDs == [59, 60])
        await viewModel.loadVisibleCast(visibleIDs: [1, 2])

        #expect(await repository.requests == [[1, 2], [59, 60]])
        #expect(Set(viewModel.characters.keys) == [1, 2, 59, 60])
    }

    @Test("A new viewport waits for the active batch and requests only remaining IDs", .timeLimit(.minutes(1)))
    func reusesInFlightBatch() async throws {
        let gate = Gate()
        let repository = CharacterBatchRecorder(firstBatchGate: gate, unavailableID: 3)
        let viewModel = makeViewModel(repository: repository)
        let first = Task { await viewModel.loadVisibleCast(visibleIDs: [1, 2]) }
        while await repository.requests.isEmpty { await Task.yield() }
        #expect(viewModel.unavailableIDs.isEmpty)

        first.cancel()
        let last = Task { await viewModel.loadVisibleCast(visibleIDs: [2, 3]) }
        while viewModel.settledIDs != [2, 3] { await Task.yield() }
        #expect(await repository.requests == [[1, 2]])
        await gate.open()
        await first.value
        await last.value

        #expect(await repository.requests == [[1, 2], [3]])
        #expect(Set(viewModel.characters.keys) == [1, 2])
        #expect(viewModel.unavailableIDs == [3])
    }
}

@MainActor
private func makeViewModel(
    characterIDs: [Int] = [], repository: CharacterBatchRecorder
) -> EpisodeCharactersViewModel {
    EpisodeCharactersViewModel(
        characterIDs: characterIDs, repository: repository, portraitLoader: PortraitLoader(repository: repository)
    )
}

private actor CharacterBatchRecorder: CharacterRepository {
    private(set) var requests: [[Int]] = []
    private(set) var portraitRequests: [URL] = []
    private(set) var singleRequests: [Int] = []
    let firstBatchGate: Gate?
    let unavailableID: Int?
    let portraitURL: URL?
    let firstPortraitError: RepositoryError?

    init(
        firstBatchGate: Gate? = nil, unavailableID: Int? = nil,
        portraitURL: URL? = nil, firstPortraitError: RepositoryError? = nil
    ) {
        self.firstBatchGate = firstBatchGate
        self.unavailableID = unavailableID
        self.portraitURL = portraitURL
        self.firstPortraitError = firstPortraitError
    }

    func characters(ids: [Int]) async -> [Int: CharacterDetails] {
        requests.append(ids)
        if requests.count == 1 {
            await firstBatchGate?.wait()
        }
        return Dictionary(uniqueKeysWithValues: ids.filter { $0 != unavailableID }.map { ($0, makeCharacter($0)) })
    }

    func character(id: Int) async throws -> CharacterDetails {
        singleRequests.append(id)
        return makeCharacter(id)
    }
    func portrait(for character: CharacterDetails) async throws -> Data {
        guard let url = character.imageURL else { throw RepositoryError.notFound }
        portraitRequests.append(url)
        if portraitRequests.count == 1, let firstPortraitError { throw firstPortraitError }
        return RecordedResponses.portrait
    }

    private func makeCharacter(_ id: Int) -> CharacterDetails {
        CharacterDetails(
            id: id, name: "Character \(id)", status: .unknown, species: "",
            originName: "", episodeCount: 0, imageURL: portraitURL
        )
    }
}
