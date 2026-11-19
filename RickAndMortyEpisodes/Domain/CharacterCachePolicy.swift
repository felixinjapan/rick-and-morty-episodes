import Foundation

/// When saved character details can be shown without asking the API again. They expire by age, or
/// when the catalogue changes size, since new episodes can add or rename characters.
struct CharacterCachePolicy: Sendable {
    let maxAge: TimeInterval

    /// A count of `nil` means it is unknown, which never counts as a change.
    func isFresh(savedAt: Date, savedCatalogueCount: Int?, currentCatalogueCount: Int?, now: Date) -> Bool {
        let sameCatalogue = currentCatalogueCount == nil || savedCatalogueCount == nil
            || savedCatalogueCount == currentCatalogueCount
        return sameCatalogue && now.timeIntervalSince(savedAt) < maxAge
    }
}
