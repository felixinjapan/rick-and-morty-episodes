import CoreGraphics

enum PortraitResult: Sendable {
    case image(CGImage)
    /// `retryable` is true for failures worth trying again later, such as being offline.
    case unavailable(retryable: Bool)
}

protocol PortraitLoading: Sendable {
    /// A display-sized portrait, or `nil` if the load was cancelled.
    func thumbnail(for character: CharacterDetails) async -> PortraitResult?
}
