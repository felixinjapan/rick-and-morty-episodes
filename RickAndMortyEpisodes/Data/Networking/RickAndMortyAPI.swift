import Foundation

protocol RickAndMortyAPI: Sendable {
    func episodes(page: Int) async throws -> EpisodePage
    func character(id: Int) async throws -> CharacterDetails
    func characters(ids: [Int]) async throws -> [CharacterDetails]
    /// The bytes of a character's portrait; throws if the response isn't an image.
    func portrait(from url: URL) async throws -> Data
}
