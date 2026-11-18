import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode character loading")
struct EpisodeCharactersLoaderTests {
    @Test("Recreated rows can reuse the same portrait from the cast cache")
    func reusesCachedPortrait() async throws {
        let url = try #require(URL(string: "https://example.com/portrait.png"))
        let otherURL = try #require(URL(string: "https://example.com/replacement.png"))
        let portraits = EpisodeCharacterPortraits()
        let repository = CharacterBatchRecorder()
        let character = CharacterDetails(
            id: 1, name: "Rick", status: .alive, species: "", originName: "", episodeCount: 1, imageURL: url
        )

        await portraits.load(for: [character, character], from: repository)
        await portraits.load(for: [], from: repository)
        await portraits.load(for: [character], from: repository)

        #expect(await repository.portraitRequests == [url])
        guard case .loaded = portraits.phase(for: url), case .loading = portraits.phase(for: otherURL) else {
            Issue.record("Expected the loaded portrait to stay available by URL")
            return
        }
    }

    @Test("Cast IDs keep their original order and discard duplicates and invalid IDs")
    func normalizesCastIDs() {
        let episode = Episode(id: 1, name: "Episode", airDate: nil, code: "", characterIDs: [3, 0, 1, -1, 3, 2, 1])
        #expect(episode.characterIDs == [3, 1, 2])
    }

    @Test("Widely separated viewports fetch only the visible records")
    func distantViewports() async {
        let repository = CharacterBatchRecorder()
        let loader = EpisodeCharactersLoader()
        let windows = stride(from: 1, through: 9_998, by: 909).map { Array($0...($0 + 2)) }

        await loader.load(visibleIDs: [], from: repository)
        for window in windows {
            await loader.load(visibleIDs: Set(window), from: repository)
        }
        await loader.load(visibleIDs: Set(windows[0]), from: repository)

        #expect(await repository.requests == windows)
        #expect(Set(loader.characters.keys) == Set(windows.joined()))
    }

    @Test("A fling skips intermediate rows and revisiting loaded rows makes no request")
    func skipsIntermediateRows() async throws {
        let repository = CharacterBatchRecorder()
        let loader = EpisodeCharactersLoader()
        await loader.load(visibleIDs: [1, 2], from: repository)

        let passingRows = Task { await loader.load(visibleIDs: [20, 21], from: repository) }
        try await Task.sleep(for: .milliseconds(35))
        #expect(loader.settledIDs == [1, 2])
        passingRows.cancel()
        await passingRows.value

        await loader.load(visibleIDs: [59, 60], from: repository)
        #expect(loader.settledIDs == [59, 60])
        await loader.load(visibleIDs: [1, 2], from: repository)

        #expect(await repository.requests == [[1, 2], [59, 60]])
        #expect(Set(loader.characters.keys) == [1, 2, 59, 60])
    }

    @Test("A new viewport waits for the active batch and requests only remaining IDs", .timeLimit(.minutes(1)))
    func reusesInFlightBatch() async throws {
        let gate = Gate()
        let repository = CharacterBatchRecorder(firstBatchGate: gate, unavailableID: 3)
        let loader = EpisodeCharactersLoader()
        let first = Task { await loader.load(visibleIDs: [1, 2], from: repository) }
        while await repository.requests.isEmpty { await Task.yield() }
        #expect(loader.unavailableIDs.isEmpty)

        first.cancel()
        let last = Task { await loader.load(visibleIDs: [2, 3], from: repository) }
        while loader.settledIDs != [2, 3] { await Task.yield() }
        #expect(await repository.requests == [[1, 2]])
        await gate.open()
        await first.value
        await last.value

        #expect(await repository.requests == [[1, 2], [3]])
        #expect(Set(loader.characters.keys) == [1, 2])
        #expect(loader.unavailableIDs == [3])
    }
}

private actor CharacterBatchRecorder: CharacterRepository {
    private(set) var requests: [[Int]] = []
    private(set) var portraitRequests: [URL] = []
    let firstBatchGate: Gate?
    let unavailableID: Int?

    init(firstBatchGate: Gate? = nil, unavailableID: Int? = nil) {
        self.firstBatchGate = firstBatchGate
        self.unavailableID = unavailableID
    }

    func characters(ids: [Int]) async -> [Int: CharacterDetails] {
        requests.append(ids)
        if requests.count == 1 {
            await firstBatchGate?.wait()
        }
        return Dictionary(uniqueKeysWithValues: ids.filter { $0 != unavailableID }.map { ($0, makeCharacter($0)) })
    }

    func character(id: Int) async throws -> CharacterDetails { makeCharacter(id) }
    func portrait(for character: CharacterDetails) async throws -> Data {
        guard let url = character.imageURL else { throw RepositoryError.notFound }
        portraitRequests.append(url)
        return RecordedResponses.portrait
    }

    private func makeCharacter(_ id: Int) -> CharacterDetails {
        CharacterDetails(
            id: id, name: "Character \(id)", status: .unknown, species: "",
            originName: "", episodeCount: 0, imageURL: nil
        )
    }
}
