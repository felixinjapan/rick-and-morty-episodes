import Foundation
import os

/// Details expire by age or catalogue size. Failed fetches fall back to saved details,
/// except for not-found responses and cancellation.
actor DefaultCharacterRepository: CharacterRepository {
    private let api: any RickAndMortyAPI
    private let store: FileCharacterStore
    private let portraits: PortraitStore
    private let catalogueCount: @Sendable () async -> Int?
    private let maxAge: TimeInterval
    private let now: @Sendable () -> Date
    private let logger = Logger(category: "DefaultCharacterRepository")
    private var cache: [Int: StoredCharacter] = [:]
    private var portraitLoads: [URL: Task<Data, any Error>] = [:]

    init(
        api: any RickAndMortyAPI,
        store: FileCharacterStore,
        portraits: PortraitStore,
        catalogueCount: @escaping @Sendable () async -> Int?,
        maxAge: TimeInterval,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.api = api
        self.store = store
        self.portraits = portraits
        self.catalogueCount = catalogueCount
        self.maxAge = maxAge
        self.now = now
    }

    func character(id: Int) async throws -> CharacterDetails {
        let current = await catalogueCount()
        let saved = await savedCharacter(id: id)
        if let saved, isFresh(saved, catalogueCount: current) {
            return saved.details
        }

        do {
            let details = try await translatingErrors(logger: logger) { try await api.character(id: id) }
            await save(details, catalogueCount: current)
            return details
        } catch let error as RepositoryError where error != .notFound {
            guard let saved else { throw error }
            logger.info("Serving saved character \(id) after: \(String(describing: error), privacy: .public)")
            return saved.details
        }
    }

    func characters(ids: [Int]) async -> [Int: CharacterDetails] {
        guard !ids.isEmpty else { return [:] }
        let current = await catalogueCount()
        var available: [Int: CharacterDetails] = [:]
        var stale: [Int: CharacterDetails] = [:]
        var idsToFetch: [Int] = []
        let sortedIDs = Set(ids).sorted()
        let saved = await savedCharacters(ids: sortedIDs)
        guard !Task.isCancelled else { return available }
        for id in sortedIDs {
            if let saved = saved[id] {
                if isFresh(saved, catalogueCount: current) {
                    available[id] = saved.details
                    continue
                }
                stale[id] = saved.details
            }
            idsToFetch.append(id)
        }
        guard !idsToFetch.isEmpty else { return available }

        do {
            try Task.checkCancellation()
            let fetched = try await translatingErrors(logger: logger) {
                try await api.characters(ids: idsToFetch)
            }
            logger.debug("Character batch downloaded \(fetched.count) records")
            let requested = Set(idsToFetch)
            let received = fetched.filter { requested.contains($0.id) }
            for details in received { available[details.id] = details }
            await save(received, catalogueCount: current)
        } catch let error as RepositoryError where error != .notFound {
            available.merge(stale) { fresh, _ in fresh }
        } catch {
            // Cancellation and not-found responses leave only the fresh cached details.
        }
        return available
    }

    /// Reuses a readable saved portrait without an age limit. A missing, unreadable, or invalid
    /// file is downloaded again; a successful download replaces it. Fetch failures propagate.
    /// Callers asking for the same URL share one load, because the actor can interleave them at
    /// each `await` and both would miss the saved file.
    func portrait(for character: CharacterDetails) async throws -> Data {
        guard let url = character.imageURL else { throw RepositoryError.notFound }
        if let running = portraitLoads[url] { return try await running.value }
        let load = Task<Data, any Error> {
            defer { portraitLoads[url] = nil }
            return try await loadPortrait(for: character, from: url)
        }
        portraitLoads[url] = load
        return try await load.value
    }

    private func loadPortrait(for character: CharacterDetails, from url: URL) async throws -> Data {
        do {
            if let saved = try await portraits.load(for: url) {
                if ImageValidation.isImage(saved) { return saved }
                logger.error("Saved portrait \(character.id) is not a readable image")
            }
        } catch {
            logger.error("Failed to read saved portrait \(character.id): \(error.localizedDescription, privacy: .public)")
        }
        let data = try await translatingErrors(logger: logger) { try await api.portrait(from: url) }
        do {
            try await portraits.save(data, for: url)
        } catch {
            logger.error("Failed to save portrait \(character.id): \(error.localizedDescription, privacy: .public)")
        }
        return data
    }

    private func isFresh(_ saved: StoredCharacter, catalogueCount current: Int?) -> Bool {
        let sameCatalogue = current == nil || saved.catalogueCount == nil || saved.catalogueCount == current
        return sameCatalogue && now().timeIntervalSince(saved.savedAt) < maxAge
    }

    private func savedCharacter(id: Int) async -> StoredCharacter? {
        if let cached = cache[id] { return cached }
        do {
            guard let loaded = try await store.load(id: id) else { return nil }
            cache[id] = loaded
            return loaded
        } catch {
            logger.error("Failed to read saved character \(id): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Reads the files for every ID missing from memory in one store call.
    private func savedCharacters(ids: [Int]) async -> [Int: StoredCharacter] {
        var saved: [Int: StoredCharacter] = [:]
        var uncached: [Int] = []
        for id in ids {
            if let cached = cache[id] { saved[id] = cached } else { uncached.append(id) }
        }
        guard !uncached.isEmpty else { return saved }
        for (id, result) in await store.load(ids: uncached) {
            switch result {
            case .success(let loaded?):
                cache[id] = loaded
                saved[id] = loaded
            case .success(nil):
                break
            case .failure(let error):
                logger.error("Failed to read saved character \(id): \(error.localizedDescription, privacy: .public)")
            }
        }
        return saved
    }

    /// A failed save only costs offline availability, so it is logged, not shown to the user.
    private func save(_ details: CharacterDetails, catalogueCount: Int?) async {
        await save([details], catalogueCount: catalogueCount)
    }

    private func save(_ characters: [CharacterDetails], catalogueCount: Int?) async {
        guard !characters.isEmpty else { return }
        let stored = characters.map { StoredCharacter(details: $0, catalogueCount: catalogueCount, savedAt: now()) }
        for character in stored { cache[character.details.id] = character }
        for (id, error) in await store.save(stored) {
            logger.error("Failed to save character \(id): \(error.localizedDescription, privacy: .public)")
        }
    }
}
