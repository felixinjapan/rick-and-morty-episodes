import Foundation

/// Cancellation propagates as `CancellationError`, rather than an API error.
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

extension APIError {
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
