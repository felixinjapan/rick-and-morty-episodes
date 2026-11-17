import Foundation

/// A character's details and the metadata used to decide when to fetch them again.
struct StoredCharacter: Sendable, Equatable {
    let details: CharacterDetails
    /// New episodes can change a character's episode count.
    let catalogueCount: Int?
    let savedAt: Date
}
