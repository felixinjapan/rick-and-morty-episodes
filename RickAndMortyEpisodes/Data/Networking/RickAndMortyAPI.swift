import Foundation

/// The API surface the app depends on. Repositories and tests use this protocol,
/// so no layer above networking knows about URLs, status codes, or JSON.
protocol RickAndMortyAPI: Sendable {
    func episodes(page: Int) async throws -> EpisodePage
    func character(id: Int) async throws -> CharacterDetails
}

/// Sends a request and returns the raw response. Production code uses `URLSession`;
/// tests pass a closure, which avoids global `URLProtocol` stubs and keeps tests parallel-safe.
struct HTTPTransport: Sendable {
    let send: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static func urlSession(_ session: URLSession) -> HTTPTransport {
        HTTPTransport { request in try await session.data(for: request) }
    }
}

struct LiveRickAndMortyAPI: RickAndMortyAPI {
    private let baseURL: URL
    private let transport: HTTPTransport

    init(baseURL: URL, transport: HTTPTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func episodes(page: Int) async throws -> EpisodePage {
        var components = URLComponents(
            url: baseURL.appending(path: "episode"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "page", value: String(page))]
        guard let url = components?.url else { throw APIError.invalidResponse }
        let dto: EpisodePageDTO = try await get(url)
        return dto.toDomain()
    }

    func character(id: Int) async throws -> CharacterDetails {
        let dto: CharacterDTO = try await get(baseURL.appending(path: "character/\(id)"))
        return dto.toDomain()
    }

    private func get<Response: Decodable>(_ url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw APIError.from(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(statusCode: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
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
