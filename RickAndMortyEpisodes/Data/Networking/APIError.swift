import Foundation

/// How a request failed, in HTTP and URL-loading terms. It stays in the Data layer:
/// `toDomain()` translates it into the domain's `EpisodeError`, like the DTOs' `toDomain()`.
/// Cancellation is deliberately not a case: it is surfaced as `CancellationError` so
/// callers can ignore it instead of showing an error.
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

// MARK: - Mapping to the domain

extension APIError {
    /// The domain's view of this failure, for code above the Data layer.
    func toDomain() -> EpisodeError {
        switch self {
        case .offline: .offline
        case .timedOut: .timedOut
        case .http(404): .notFound
        case .http(429): .rateLimited
        case .http(let status) where status >= 500: .serverUnavailable
        case .invalidResponse: .serverUnavailable
        case .decoding: .unreadableData
        case .transport, .http: .failed
        }
    }
}
