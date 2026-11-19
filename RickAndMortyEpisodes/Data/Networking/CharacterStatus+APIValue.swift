import Foundation

/// The API's wording, which the on-disk cache keeps too, so both read it the same way.
extension CharacterStatus {
    init(apiValue: String) {
        self = Self(rawValue: apiValue.lowercased()) ?? .unknown
    }
}
