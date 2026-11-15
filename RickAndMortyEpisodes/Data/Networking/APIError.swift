import Foundation

/// How a request failed, in HTTP and URL-loading terms. It stays in the Data layer; `toDomain()`
/// translates it into `DataError`. Cancellation isn't a case: it surfaces as `CancellationError`,
/// so callers can ignore it.
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
    /// This failure in the domain's terms.
    func toDomain() -> DataError {
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
