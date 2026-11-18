import Foundation
@testable import RickAndMortyEpisodes

actor StubAPI: RickAndMortyAPI {
    private var pages: [Int: Result<EpisodePage, any Error>]
    private var characters: [Int: Result<CharacterDetails, any Error>]
    private let portraits: [URL: Result<Data, any Error>]
    private var pageGates: [Int: Gate] = [:]
    private(set) var requestedPages: [Int] = []
    private(set) var requestedCharacters: [Int] = []
    private(set) var requestedCharacterBatches: [[Int]] = []
    private(set) var requestedPortraits: [URL] = []

    init(
        pages: [Int: Result<EpisodePage, any Error>] = [:],
        characters: [Int: Result<CharacterDetails, any Error>] = [:],
        portraits: [URL: Result<Data, any Error>] = [:]
    ) {
        self.pages = pages
        self.characters = characters
        self.portraits = portraits
    }

    func setPage(_ page: Int, _ result: Result<EpisodePage, any Error>) {
        pages[page] = result
    }

    func setCharacter(_ id: Int, _ result: Result<CharacterDetails, any Error>) {
        characters[id] = result
    }

    func holdPage(_ page: Int, until gate: Gate?) {
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

    func characters(ids: [Int]) async throws -> [CharacterDetails] {
        requestedCharacterBatches.append(ids)
        return try ids.compactMap { try characters[$0]?.get() }
    }

    func portrait(from url: URL) async throws -> Data {
        requestedPortraits.append(url)
        guard let result = portraits[url] else { throw APIError.http(statusCode: 404) }
        return try result.get()
    }
}

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
    static func makeTemporary() -> FileEpisodeStore {
        FileEpisodeStore(fileURL: .temporaryDirectory.appending(path: "\(UUID().uuidString)/\(defaultFileName)"))
    }

    static func makeTemporary(containing snapshot: EpisodeSnapshot) async throws -> FileEpisodeStore {
        let store = makeTemporary()
        try await store.save(snapshot)
        return store
    }

    static func makeUnwritable() throws -> FileEpisodeStore {
        try FileEpisodeStore(fileURL: makeTemporaryBlockingFile().appending(path: defaultFileName))
    }
}

extension FileCharacterStore {
    static func makeTemporary() -> FileCharacterStore {
        FileCharacterStore(directory: .temporaryDirectory.appending(path: "\(UUID().uuidString)/characters"))
    }

    static func makeUnwritable() throws -> FileCharacterStore {
        try FileCharacterStore(directory: makeTemporaryBlockingFile().appending(path: "characters"))
    }
}

extension PortraitStore {
    static func makeTemporary() -> PortraitStore {
        PortraitStore(directory: .temporaryDirectory.appending(path: "\(UUID().uuidString)/portraits"))
    }

    static func makeUnwritable() throws -> PortraitStore {
        try PortraitStore(directory: makeTemporaryBlockingFile().appending(path: "portraits"))
    }
}

func makeTemporaryBlockingFile() throws -> URL {
    let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try Data().write(to: url)
    return url
}

extension DefaultCharacterRepository {
    static func makeTemporary(
        api: any RickAndMortyAPI,
        store: FileCharacterStore = .makeTemporary(),
        portraits: PortraitStore = .makeTemporary(),
        catalogueCount: @escaping @Sendable () async -> Int? = { nil },
        maxAge: TimeInterval = 3600,
        now: @escaping @Sendable () -> Date = { fixedDate }
    ) -> DefaultCharacterRepository {
        DefaultCharacterRepository(
            api: api, store: store, portraits: portraits, catalogueCount: catalogueCount, maxAge: maxAge, now: now
        )
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

func makeThreePageAPI() -> StubAPI {
    StubAPI(pages: [
        1: .success(.make(ids: 1...20, hasNextPage: true)),
        2: .success(.make(ids: 21...40, hasNextPage: true)),
        3: .success(.make(ids: 41...45, hasNextPage: false)),
    ])
}
