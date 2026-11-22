import CoreGraphics

enum PortraitResult: Sendable {
    case image(CGImage)
    /// `retryable` is true for failures worth trying again later, such as being offline.
    case unavailable(retryable: Bool)
}

/// Loads a display-sized portrait, or returns `nil` if the load was cancelled.
typealias LoadThumbnail = @Sendable (CharacterDetails) async -> PortraitResult?
