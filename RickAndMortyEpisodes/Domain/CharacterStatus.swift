import Foundation

/// Whether a character is alive. The API sends "Alive", "Dead" or "unknown".
enum CharacterStatus: Sendable, Hashable {
    case alive
    case dead
    case unknown
}
