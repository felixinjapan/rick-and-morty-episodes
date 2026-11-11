import Foundation

struct CharacterDetails: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    let status: String
    let species: String
    let originName: String
    let episodeCount: Int
    let imageURL: URL?
}
