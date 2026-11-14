import Foundation

/// The API surface the app depends on. Repositories and tests use this protocol,
/// so no layer above networking knows about URLs, status codes, or JSON.
protocol RickAndMortyAPI: Sendable {
    func episodes(page: Int) async throws -> EpisodePage
    func character(id: Int) async throws -> CharacterDetails
}
