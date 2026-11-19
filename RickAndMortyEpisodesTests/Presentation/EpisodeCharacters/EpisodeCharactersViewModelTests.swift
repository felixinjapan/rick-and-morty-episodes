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
        let recoveringModel = makeViewModel(characterIDs: [1], repository: recovering)
        let missingModel = makeViewModel(characterIDs: [1], repository: missing)

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

    @Test("The first request is small, and the next 80 follow on their own")
    func firstChunkThenSecond() async {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(characterIDs: Array(1...300), repository: repository)

        await viewModel.loadVisibleCast(visibleIDs: [1, 2, 3])

        #expect(await repository.requests == [Array(1...20), Array(21...100)])
        #expect(Set(viewModel.characters.keys) == Set(1...100))
    }

    @Test("Visible portraits load before the prefetch chunk is requested", .timeLimit(.minutes(1)))
    func portraitsBeforePrefetch() async throws {
        let url = try #require(URL(string: "https://example.com/portrait.png"))
        let gate = Gate()
        let repository = CharacterBatchRecorder(secondBatchGate: gate, portraitURL: url)
        let viewModel = makeViewModel(characterIDs: Array(1...300), repository: repository)
        let loading = Task { await viewModel.loadVisibleCast(visibleIDs: [1, 2, 3]) }

        while await repository.requests.count < 2 { await Task.yield() }

        #expect(await repository.portraitRequests == [url])
        #expect(Set(viewModel.characters.keys) == Set(1...20))
        await gate.open()
        await loading.value
        #expect(Set(viewModel.characters.keys) == Set(1...100))
    }

    @Test("A short cast is complete after one request")
    func shortCast() async {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(characterIDs: Array(1...15), repository: repository)

        await viewModel.loadVisibleCast(visibleIDs: [1, 2])
        await viewModel.loadVisibleCast(visibleIDs: [14, 15])

        #expect(await repository.requests == [Array(1...15)])
    }

    @Test("The next 80 are requested once a row is 80% through the loaded chunk, not before")
    func prefetchesNextChunk() async {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(characterIDs: Array(1...400), repository: repository)
        await viewModel.loadVisibleCast(visibleIDs: [1])

        await viewModel.loadVisibleCast(visibleIDs: [84])
        #expect(await repository.requests == [Array(1...20), Array(21...100)])

        await viewModel.loadVisibleCast(visibleIDs: [85])
        #expect(await repository.requests == [Array(1...20), Array(21...100), Array(101...180)])
    }

    @Test("A far jump loads the chunk around the destination, not the chunks in between")
    func distantViewports() async {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(characterIDs: Array(1...10_000), repository: repository)

        await viewModel.loadVisibleCast(visibleIDs: [])
        await viewModel.loadVisibleCast(visibleIDs: [1, 2, 3])
        await viewModel.loadVisibleCast(visibleIDs: [5_001, 5_002, 5_003])
        await viewModel.loadVisibleCast(visibleIDs: [5_046, 5_047, 5_048])
        await viewModel.loadVisibleCast(visibleIDs: [1, 2, 3])

        #expect(await repository.requests == [
            Array(1...20), Array(21...100), Array(4_981...5_060), Array(5_061...5_140),
        ])
        #expect(viewModel.characters.count == 260)
    }

    @Test("Opening a character from the cast reuses loaded details and saves a fallback lookup")
    func opensCharacterFromCast() async throws {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(characterIDs: Array(1...300), repository: repository)
        await viewModel.loadVisibleCast(visibleIDs: [4])

        #expect(try await viewModel.character(id: 8).id == 8)
        #expect(await repository.singleRequests.isEmpty)
        #expect(try await viewModel.character(id: 300).id == 300)
        #expect(try await viewModel.character(id: 300).id == 300)
        #expect(await repository.singleRequests == [300])
    }

    @Test("A fling skips intermediate rows and revisiting loaded rows makes no request")
    func skipsIntermediateRows() async throws {
        let repository = CharacterBatchRecorder()
        let viewModel = makeViewModel(characterIDs: Array(1...1_000), repository: repository)
        await viewModel.loadVisibleCast(visibleIDs: [1, 2])

        let passingRows = Task { await viewModel.loadVisibleCast(visibleIDs: [200, 201]) }
        try await Task.sleep(for: .milliseconds(35))
        #expect(viewModel.settledIDs == [1, 2])
        passingRows.cancel()
        await passingRows.value

        await viewModel.loadVisibleCast(visibleIDs: [599, 600])
        #expect(viewModel.settledIDs == [599, 600])
        await viewModel.loadVisibleCast(visibleIDs: [1, 2])

        #expect(await repository.requests == [Array(1...20), Array(21...100), Array(581...660)])
        #expect(viewModel.characters.count == 180)
    }

    @Test("A new viewport waits for the active batch and requests only remaining IDs", .timeLimit(.minutes(1)))
    func reusesInFlightBatch() async throws {
        let gate = Gate()
        let repository = CharacterBatchRecorder(firstBatchGate: gate, unavailableID: 3)
        let viewModel = makeViewModel(characterIDs: Array(1...300), repository: repository)
        let first = Task { await viewModel.loadVisibleCast(visibleIDs: [1, 2]) }
        while await repository.requests.isEmpty { await Task.yield() }
        #expect(viewModel.unavailableIDs.isEmpty)

        first.cancel()
        let last = Task { await viewModel.loadVisibleCast(visibleIDs: [2, 3]) }
        while viewModel.settledIDs != [2, 3] { await Task.yield() }
        #expect(await repository.requests == [Array(1...20)])
        await gate.open()
        await first.value
        await last.value

        #expect(await repository.requests == [Array(1...20), [3], Array(21...100)])
        #expect(Set(viewModel.characters.keys) == Set(1...100).subtracting([3]))
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
    let secondBatchGate: Gate?
    let unavailableID: Int?
    let portraitURL: URL?
    let firstPortraitError: RepositoryError?

    init(
        firstBatchGate: Gate? = nil, secondBatchGate: Gate? = nil, unavailableID: Int? = nil,
        portraitURL: URL? = nil, firstPortraitError: RepositoryError? = nil
    ) {
        self.firstBatchGate = firstBatchGate
        self.secondBatchGate = secondBatchGate
        self.unavailableID = unavailableID
        self.portraitURL = portraitURL
        self.firstPortraitError = firstPortraitError
    }

    func characters(ids: [Int]) async -> [Int: CharacterDetails] {
        requests.append(ids)
        if requests.count == 1 {
            await firstBatchGate?.wait()
        } else if requests.count == 2 {
            await secondBatchGate?.wait()
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
