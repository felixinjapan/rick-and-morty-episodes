import Foundation

extension DataError {
    /// The sentence shown to the user, from the string catalog.
    var message: String {
        switch self {
        case .offline: String(localized: .errorOffline)
        case .timedOut: String(localized: .errorTimedOut)
        case .notFound: String(localized: .errorNotFound)
        case .rateLimited: String(localized: .errorRateLimited)
        case .serverUnavailable: String(localized: .errorServerUnavailable)
        case .unreadableData: String(localized: .errorUnreadableData)
        case .failed: String(localized: .errorFailed)
        }
    }
}

extension Error {
    /// Message for the UI. The repository only throws `DataError` (or cancellation),
    /// so anything else falls back to the generic text.
    var userMessage: String {
        ((self as? DataError) ?? .failed).message
    }
}
