import Foundation
import os

/// The real API client: builds requests, sends them through an `HTTPTransport`, checks
/// the status and maps the JSON to domain entities. Errors are reported as `APIError`.
struct LiveRickAndMortyAPI: RickAndMortyAPI {
    private static let logger = Logger(category: "LiveRickAndMortyAPI")

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

    func portrait(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let data = try await send(request)
        // It will be saved on disk, so make sure it is an image and not, say, an error page.
        guard ImageValidation.isImage(data) else {
            Self.logger.error("The portrait from \(url, privacy: .public) is not an image")
            throw APIError.decoding
        }
        return data
    }

    private func get<Response: Decodable>(_ url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await send(request)

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            // The error names the field and type that didn't match, which is what's needed to
            // diagnose an API change. It contains no user data: the API is public.
            Self.logger.error("""
                Decoding \(Response.self, privacy: .public) from \(url, privacy: .public) failed: \
                \(String(describing: error), privacy: .public)
                """)
            throw APIError.decoding
        }
    }

    /// Sends the request and returns the body of a successful response.
    private func send(_ request: URLRequest) async throws -> Data {
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
        return data
    }
}
