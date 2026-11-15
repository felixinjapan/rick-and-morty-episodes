import Foundation
import os

/// Character details and portraits from the API, saved on disk once the user has opened them, so
/// opening the same character again makes no request and works offline. Only opened characters are saved; nothing is
/// downloaded ahead of time. An actor because the cache is mutable state shared by screens.
///
/// Saved details are used while the catalogue is the same size as when they were saved and they are
/// younger than `maxAge`. Otherwise they are fetched again; if that fails they are still served, so a
/// character the user has opened never turns into an error screen just because the data is old.
actor DefaultCharacterRepository: CharacterRepository {
    private let api: any RickAndMortyAPI
    private let store: FileCharacterStore
    private let portraits: PortraitStore
    /// The catalogue size now, or `nil` if unknown.
    private let catalogueCount: @Sendable () async -> Int?
    private let maxAge: TimeInterval
    private let now: @Sendable () -> Date
    private let logger = Logger(category: "DefaultCharacterRepository")
    /// Saved characters read or written during this session, so repeat visits skip the file.
    private var cache: [Int: StoredCharacter] = [:]

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
            let stored = StoredCharacter(details: details, catalogueCount: current, savedAt: now())
            cache[id] = stored
            await persist(stored)
            return details
        } catch let error as DataError where error != .notFound {
            // Offline, timed out or the server failed: older details beat an error screen.
            guard let saved else { throw error }
            logger.info("Serving saved character \(id) after: \(String(describing: error), privacy: .public)")
            return saved.details
        }
    }

    /// Saved portraits are never dropped or refetched: the image URL names the character, so the
    /// image behind it doesn't change.
    func portrait(for character: CharacterDetails) async throws -> Data {
        guard let url = character.imageURL else { throw DataError.notFound }
        do {
            if let saved = try await portraits.load(for: url) { return saved }
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

    /// An unreadable file is logged and treated as not saved.
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

    /// A failed save only costs offline availability, so it is logged, not shown to the user.
    private func persist(_ stored: StoredCharacter) async {
        do {
            try await store.save(stored)
        } catch {
            logger.error("Failed to save character \(stored.details.id): \(error.localizedDescription, privacy: .public)")
        }
    }
}
