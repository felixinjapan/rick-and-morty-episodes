import Foundation

struct CharacterDetails: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let status: CharacterStatus
    let species: String
    let originName: String
    let episodeCount: Int
    let imageURL: URL?
}
