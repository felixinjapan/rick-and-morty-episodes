import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Portrait repository")
struct PortraitRepositoryTests {
    private static let avatar = URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")!

    @Test("A portrait is downloaded once and then read from disk")
    func downloadedOnce() async throws {
        let api = StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)])
        let repository = DefaultPortraitRepository.makeTemporary(api: api)

        let first = try await repository.portrait(for: .rick)
        let second = try await repository.portrait(for: .rick)

        #expect(first == RecordedResponses.portrait)
        #expect(second == first)
        #expect(await api.requestedPortraits == [Self.avatar])
    }

    @Test("A portrait seen in an earlier session is read from disk, with no request")
    func savedAcrossSessions() async throws {
        let store = PortraitStore.makeTemporary()
        let first = DefaultPortraitRepository.makeTemporary(
            api: StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)]), store: store
        )
        _ = try await first.portrait(for: .rick)

        let api = StubAPI()
        let second = DefaultPortraitRepository.makeTemporary(api: api, store: store)

        #expect(try await second.portrait(for: .rick) == RecordedResponses.portrait)
        #expect(await api.requestedPortraits.isEmpty)
    }

    @Test("A saved portrait is served when the network is gone")
    func savedPortraitServedOffline() async throws {
        let store = PortraitStore.makeTemporary()
        let online = DefaultPortraitRepository.makeTemporary(
            api: StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)]), store: store
        )
        _ = try await online.portrait(for: .rick)

        let offline = DefaultPortraitRepository.makeTemporary(
            api: StubAPI(portraits: [Self.avatar: .failure(APIError.offline)]), store: store
        )

        #expect(try await offline.portrait(for: .rick) == RecordedResponses.portrait)
    }

    @Test("Callers asking for the same portrait at once share one download")
    func concurrentCallersShareOneDownload() async throws {
        let api = StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)])
        let repository = DefaultPortraitRepository.makeTemporary(api: api)

        async let first = repository.portrait(for: .rick)
        async let second = repository.portrait(for: .rick)
        async let third = repository.portrait(for: .rick)
        let results = try await [first, second, third]

        #expect(results.allSatisfy { $0 == RecordedResponses.portrait })
        #expect(await api.requestedPortraits == [Self.avatar])
    }

    @Test("A saved portrait that is not a readable image is downloaded again and replaced")
    func damagedPortraitIsReplaced() async throws {
        let store = PortraitStore.makeTemporary()
        try await store.save(Data("damaged".utf8), for: Self.avatar)
        let api = StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)])
        let repository = DefaultPortraitRepository.makeTemporary(api: api, store: store)

        #expect(try await repository.portrait(for: .rick) == RecordedResponses.portrait)

        #expect(await api.requestedPortraits == [Self.avatar])
        #expect(try await store.load(for: Self.avatar) == RecordedResponses.portrait)
    }

    @Test("A damaged saved portrait with no network fails, so the view shows its placeholder")
    func damagedPortraitOffline() async throws {
        let store = PortraitStore.makeTemporary()
        try await store.save(Data("damaged".utf8), for: Self.avatar)
        let api = StubAPI(portraits: [Self.avatar: .failure(APIError.offline)])
        let repository = DefaultPortraitRepository.makeTemporary(api: api, store: store)

        await #expect(throws: RepositoryError.offline) { try await repository.portrait(for: .rick) }
    }

    @Test("A portrait that was never seen fails with a domain error", arguments: apiToDomainErrors)
    func errorTranslation(apiError: APIError, expected: RepositoryError) async {
        let repository = DefaultPortraitRepository.makeTemporary(
            api: StubAPI(portraits: [Self.avatar: .failure(apiError)])
        )
        await #expect(throws: expected) { try await repository.portrait(for: .rick) }
    }

    @Test("A character without an image URL has no portrait")
    func noImageURL() async {
        let withoutImage = CharacterDetails(
            id: 9, name: "X", status: .alive, species: "Alien", originName: "Y", episodeCount: 1, imageURL: nil
        )
        let repository = DefaultPortraitRepository.makeTemporary(api: StubAPI())
        await #expect(throws: RepositoryError.notFound) { try await repository.portrait(for: withoutImage) }
    }

    @Test("A failed portrait save doesn't fail the load")
    func saveFailureIsIgnored() async throws {
        let api = StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)])
        let repository = DefaultPortraitRepository.makeTemporary(api: api, store: try .makeUnwritable())

        #expect(try await repository.portrait(for: .rick) == RecordedResponses.portrait)
    }

    @Test("A cancelled portrait download is not answered with anything")
    func cancellation() async {
        let api = StubAPI(portraits: [Self.avatar: .failure(CancellationError())])
        let repository = DefaultPortraitRepository.makeTemporary(api: api)
        await #expect(throws: CancellationError.self) { try await repository.portrait(for: .rick) }
    }
}
