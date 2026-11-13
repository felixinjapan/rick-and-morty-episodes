import Foundation

/// Failures the UI can reason about. Cancellation is deliberately not a case: it is
/// surfaced as `CancellationError` so callers can ignore it instead of showing an error.
enum APIError: Error, Equatable {
    case offline
    case timedOut
    case transport(URLError.Code)
    case invalidResponse
    case http(statusCode: Int)
    case decoding

    static func from(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            .offline
        case .timedOut:
            .timedOut
        default:
            .transport(error.code)
        }
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .offline:
            "You appear to be offline. Check your connection, then try again."
        case .timedOut:
            "The server took too long to respond. Try again in a moment."
        case .transport:
            "A network error occurred. Try again in a moment."
        case .invalidResponse:
            "The server sent an unexpected response. Try again later."
        case .http(404):
            "This item could not be found."
        case .http(429):
            "Too many requests. Please try again in a moment."
        case .http(let statusCode) where statusCode >= 500:
            "The server is having problems. Please try again later."
        case .http:
            "The request failed. Try again later."
        case .decoding:
            "The server's data could not be read. Try again later."
        }
    }
}

extension Error {
    /// Message for the UI; falls back to a generic text for unexpected error types.
    var userMessage: String {
        (self as? LocalizedError)?.errorDescription ?? "Something went wrong."
    }
}
