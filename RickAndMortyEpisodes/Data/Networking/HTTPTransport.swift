import Foundation

/// Sends a request and returns the raw response. Production code uses `URLSession`;
/// tests pass a closure, which avoids global `URLProtocol` stubs and keeps tests parallel-safe.
struct HTTPTransport: Sendable {
    let send: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static func urlSession(_ session: URLSession) -> HTTPTransport {
        HTTPTransport { request in try await session.data(for: request) }
    }
}

extension URLSession {
    /// The session for the API. The timeouts come from `AppConfiguration`.
    static func api(requestTimeout: TimeInterval, resourceTimeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
