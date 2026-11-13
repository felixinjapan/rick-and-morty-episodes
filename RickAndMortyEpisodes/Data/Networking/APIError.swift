import Foundation

/// How a request failed, in HTTP and URL-loading terms. It stays in the Data layer:
/// `DefaultEpisodeRepository` translates it into the domain's `EpisodeError`.
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
