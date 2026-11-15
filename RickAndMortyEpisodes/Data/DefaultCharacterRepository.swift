import Foundation
import os

/// Character details from the API, kept in memory for the session so revisiting a screen doesn't
/// download them again. An actor because the cache is mutable state shared by screens.
actor DefaultCharacterRepository: CharacterRepository {
    private let api: any RickAndMortyAPI
    private let logger = Logger(category: "DefaultCharacterRepository")
    private var cache: [Int: CharacterDetails] = [:]

    init(api: any RickAndMortyAPI) {
        self.api = api
    }

    func character(id: Int) async throws -> CharacterDetails {
        if let cached = cache[id] {
            return cached
        }
        let character = try await translatingErrors(logger: logger) { try await api.character(id: id) }
        cache[id] = character
        return character
    }
}
