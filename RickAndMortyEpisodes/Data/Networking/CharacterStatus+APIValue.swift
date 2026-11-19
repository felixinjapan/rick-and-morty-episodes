import Foundation

extension CharacterStatus {
    init(apiValue: String) {
        self = Self(rawValue: apiValue.lowercased()) ?? .unknown
    }
}
