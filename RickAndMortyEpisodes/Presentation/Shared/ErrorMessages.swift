import Foundation

extension DataError {
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
    var userMessage: String {
        ((self as? DataError) ?? .failed).message
    }
}
