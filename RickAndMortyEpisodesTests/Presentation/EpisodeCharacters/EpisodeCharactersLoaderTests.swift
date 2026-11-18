import Foundation
import Testing
@testable import RickAndMortyEpisodes

@MainActor
@Suite("Episode character loading")
struct EpisodeCharactersLoaderTests {
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
    func portrait(for character: CharacterDetails) async throws -> Data { throw RepositoryError.notFound }

    private func makeCharacter(_ id: Int) -> CharacterDetails {
        CharacterDetails(
            id: id, name: "Character \(id)", status: .unknown, species: "",
            originName: "", episodeCount: 0, imageURL: nil
        )
    }
}
