import Foundation

/// Closure injection avoids global URLProtocol stubs, keeping tests parallel-safe.
struct HTTPTransport: Sendable {
    let send: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static func urlSession(_ session: URLSession) -> HTTPTransport {
        HTTPTransport { request in try await session.data(for: request) }
    }
}

extension URLSession {
    static func api(requestTimeout: TimeInterval, resourceTimeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
