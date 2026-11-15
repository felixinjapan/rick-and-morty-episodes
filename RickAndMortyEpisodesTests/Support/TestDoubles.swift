import Foundation
@testable import RickAndMortyEpisodes

/// Configurable API fake that records which requests were made.
actor StubAPI: RickAndMortyAPI {
    private var pages: [Int: Result<EpisodePage, any Error>]
    private var characters: [Int: Result<CharacterDetails, any Error>]
    private var pageGates: [Int: Gate] = [:]
    private(set) var requestedPages: [Int] = []
    private(set) var requestedCharacters: [Int] = []

    init(
        pages: [Int: Result<EpisodePage, any Error>] = [:],
        characters: [Int: Result<CharacterDetails, any Error>] = [:]
    ) {
        self.pages = pages
        self.characters = characters
    }

    func setPage(_ page: Int, _ result: Result<EpisodePage, any Error>) {
        pages[page] = result
    }

    /// Holds requests for `page` until the gate opens, to control timing in concurrency tests.
    func holdPage(_ page: Int, until gate: Gate) {
        pageGates[page] = gate
    }

    func episodes(page: Int) async throws -> EpisodePage {
        requestedPages.append(page)
        if let gate = pageGates[page] {
            await gate.wait()
        }
        try Task.checkCancellation()
        guard let result = pages[page] else { throw APIError.http(statusCode: 404) }
        return try result.get()
    }

    func character(id: Int) async throws -> CharacterDetails {
        requestedCharacters.append(id)
        guard let result = characters[id] else { throw APIError.http(statusCode: 404) }
        return try result.get()
    }
}

/// An async latch: `wait()` suspends until `open()` is called.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

extension FileEpisodeStore {
    /// A real store in its own temporary folder, so tests don't share state.
    static func makeTemporary() -> FileEpisodeStore {
        FileEpisodeStore(fileURL: .temporaryDirectory.appending(path: "\(UUID().uuidString)/episodes-cache.json"))
    }

    static func makeTemporary(containing snapshot: EpisodeSnapshot) async throws -> FileEpisodeStore {
        let store = makeTemporary()
        try await store.save(snapshot)
        return store
    }

    /// A store whose saves fail, because a file sits where its folder should be.
    static func makeUnwritable() throws -> FileEpisodeStore {
        let blocker = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try Data().write(to: blocker)
        return FileEpisodeStore(fileURL: blocker.appending(path: "episodes-cache.json"))
    }
}

// MARK: - Builders

extension Episode {
    static func make(id: Int) -> Episode {
        Episode(
            id: id, name: "Episode \(id)", airDate: Date(timeIntervalSince1970: 1_385_942_400),
            code: "S01E\(id)", characterIDs: [1, 2]
        )
    }
}

extension EpisodePage {
    /// `totalCount` is the three-page catalogue of `makeThreePageAPI`.
    static func make(ids: ClosedRange<Int>, hasNextPage: Bool, totalCount: Int = 45) -> EpisodePage {
        EpisodePage(episodes: ids.map(Episode.make), hasNextPage: hasNextPage, totalCount: totalCount)
    }
}

extension CharacterDetails {
    static let rick = CharacterDetails(
        id: 1,
        name: "Rick Sanchez",
        status: .alive,
        species: "Human",
        originName: "Earth (C-137)",
        episodeCount: 51,
        imageURL: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")
    )
}

let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

/// Three pages (20 + 20 + 5 episodes), like the real API's shape.
func makeThreePageAPI() -> StubAPI {
    StubAPI(pages: [
        1: .success(.make(ids: 1...20, hasNextPage: true)),
        2: .success(.make(ids: 21...40, hasNextPage: true)),
        3: .success(.make(ids: 41...45, hasNextPage: false)),
    ])
}
