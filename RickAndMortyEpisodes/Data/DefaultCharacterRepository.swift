import Foundation
import os

/// The app's `CharacterRepository`: character details from the API, kept in memory for the
/// session so going back and forth between screens doesn't re-download them.
///
/// An actor because the cache is mutable state that more than one screen can reach.
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
