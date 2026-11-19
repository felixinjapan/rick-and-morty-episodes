import Foundation
import os

/// Details expire by age or catalogue size. Failed fetches fall back to saved details,
/// except for not-found responses and cancellation.
actor DefaultCharacterRepository: CharacterRepository {
    private let api: any RickAndMortyAPI
    private let store: FileCharacterStore
    private let catalogueCount: @Sendable () async -> Int?
    private let policy: CharacterCachePolicy
    private let now: @Sendable () -> Date
    private let logger = Logger(category: "DefaultCharacterRepository")
    private var cache: [Int: StoredCharacter] = [:]

    init(
        api: any RickAndMortyAPI,
        store: FileCharacterStore,
        catalogueCount: @escaping @Sendable () async -> Int?,
        policy: CharacterCachePolicy,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.api = api
        self.store = store
        self.catalogueCount = catalogueCount
        self.policy = policy
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
        let sortedIDs = Set(ids).sorted()
        let saved = await savedCharacters(ids: sortedIDs)
        guard !Task.isCancelled else { return [:] }
        let (fresh, stale, idsToFetch) = partition(sortedIDs, saved: saved, catalogueCount: current)
        guard !idsToFetch.isEmpty else { return fresh }

        var available = fresh
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

    private func partition(
        _ ids: [Int], saved: [Int: StoredCharacter], catalogueCount current: Int?
    ) -> (fresh: [Int: CharacterDetails], stale: [Int: CharacterDetails], toFetch: [Int]) {
        var fresh: [Int: CharacterDetails] = [:]
        var stale: [Int: CharacterDetails] = [:]
        var toFetch: [Int] = []
        for id in ids {
            if let saved = saved[id] {
                if isFresh(saved, catalogueCount: current) {
                    fresh[id] = saved.details
                    continue
                }
                stale[id] = saved.details
            }
            toFetch.append(id)
        }
        return (fresh, stale, toFetch)
    }

    private func isFresh(_ saved: StoredCharacter, catalogueCount current: Int?) -> Bool {
        policy.isFresh(
            savedAt: saved.savedAt, savedCatalogueCount: saved.catalogueCount,
            currentCatalogueCount: current, now: now()
        )
    }

    private func savedCharacter(id: Int) async -> StoredCharacter? {
        await savedCharacters(ids: [id])[id]
    }

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
