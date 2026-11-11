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

/// Store fake whose saves can be made to fail.
actor RecordingStore: EpisodeStore {
    private(set) var snapshot: EpisodeSnapshot?
    private(set) var saveCount = 0
    private let failsOnLoad: Bool

    init(snapshot: EpisodeSnapshot? = nil, failsOnLoad: Bool = false) {
        self.snapshot = snapshot
        self.failsOnLoad = failsOnLoad
    }

    func load() throws -> EpisodeSnapshot? {
        if failsOnLoad { throw CocoaError(.fileReadCorruptFile) }
        return snapshot
    }

    func save(_ snapshot: EpisodeSnapshot) {
        saveCount += 1
        self.snapshot = snapshot
    }
}

// MARK: - Builders

extension Episode {
    static func make(id: Int) -> Episode {
        Episode(id: id, name: "Episode \(id)", airDate: "December 2, 2013", code: "S01E\(id)", characterIDs: [1, 2])
    }
}

extension EpisodePage {
    static func make(ids: ClosedRange<Int>, pageCount: Int, hasNextPage: Bool) -> EpisodePage {
        EpisodePage(episodes: ids.map(Episode.make), pageCount: pageCount, hasNextPage: hasNextPage)
    }
}

extension CharacterDetails {
    static let rick = CharacterDetails(
        id: 1,
        name: "Rick Sanchez",
        status: "Alive",
        species: "Human",
        originName: "Earth (C-137)",
        episodeCount: 51,
        imageURL: URL(string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg")
    )
}

let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

/// Three pages (20 + 20 + 5 episodes), like the real API's shape.
func threePageAPI() -> StubAPI {
    StubAPI(pages: [
        1: .success(.make(ids: 1...20, pageCount: 3, hasNextPage: true)),
        2: .success(.make(ids: 21...40, pageCount: 3, hasNextPage: true)),
        3: .success(.make(ids: 41...45, pageCount: 3, hasNextPage: false)),
    ])
}

// MARK: - Fixtures

private final class BundleToken {}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}
