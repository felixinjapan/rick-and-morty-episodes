import Foundation

struct StoredCharacter: Sendable, Equatable {
    let details: CharacterDetails
    /// The catalogue size when the details were saved, if known. New episodes change a character's
    /// episode count, so a different size means the details may be out of date.
    let catalogueCount: Int?
    let savedAt: Date
}
