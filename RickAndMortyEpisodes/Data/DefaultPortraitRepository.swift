import Foundation
import os

/// Reuses a readable saved portrait without an age limit. A missing, unreadable, or invalid
/// file is downloaded again; a successful download replaces it. Fetch failures propagate.
actor DefaultPortraitRepository: PortraitRepository {
    private let api: any RickAndMortyAPI
    private let store: PortraitStore
    private let logger = Logger(category: "DefaultPortraitRepository")
    private var loads: [URL: Task<Data, any Error>] = [:]

    init(api: any RickAndMortyAPI, store: PortraitStore) {
        self.api = api
        self.store = store
    }

    /// Callers asking for the same URL share one load, because the actor can interleave them at
    /// each `await` and both would miss the saved file.
    func portrait(for character: CharacterDetails) async throws -> Data {
        guard let url = character.imageURL else { throw RepositoryError.notFound }
        if let running = loads[url] { return try await running.value }
        let load = Task<Data, any Error> {
            defer { loads[url] = nil }
            return try await loadPortrait(for: character, from: url)
        }
        loads[url] = load
        return try await load.value
    }

    private func loadPortrait(for character: CharacterDetails, from url: URL) async throws -> Data {
        do {
            if let saved = try await store.load(for: url) {
                if ImageValidation.isImage(saved) { return saved }
                logger.error("Saved portrait \(character.id) is not a readable image")
            }
        } catch {
            logger.error("Failed to read saved portrait \(character.id): \(error.localizedDescription, privacy: .public)")
        }
        let data = try await translatingErrors(logger: logger) { try await api.portrait(from: url) }
        do {
            try await store.save(data, for: url)
        } catch {
            logger.error("Failed to save portrait \(character.id): \(error.localizedDescription, privacy: .public)")
        }
        return data
    }
}
