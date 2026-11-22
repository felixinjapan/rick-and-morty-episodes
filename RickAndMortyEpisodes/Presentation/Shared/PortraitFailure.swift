import Foundation

enum PortraitFailure: Equatable {
    /// Likely to pass on its own: try once more after the delay.
    case transient(delay: Duration)
    /// Worth asking for again later, such as when the device is back online.
    case retryLater
    case permanent

    init(_ error: RepositoryError) {
        switch error {
        case .timedOut, .serverUnavailable: self = .transient(delay: .milliseconds(500))
        case .rateLimited: self = .transient(delay: .seconds(2))
        case .offline, .failed: self = .retryLater
        case .notFound, .unreadableData: self = .permanent
        }
    }
}
