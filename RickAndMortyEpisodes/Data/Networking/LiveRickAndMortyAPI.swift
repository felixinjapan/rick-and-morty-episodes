import Foundation

/// The real API client: builds requests, sends them through an `HTTPTransport`, checks
/// the status and maps the JSON to domain entities. Errors are reported as `APIError`.
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
