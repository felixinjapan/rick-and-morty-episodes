import Foundation
import os

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

    func characters(ids: [Int]) async throws -> [CharacterDetails] {
        guard let first = ids.first else { return [] }
        if ids.count == 1 { return [try await character(id: first)] }
        let path = ids.map(String.init).joined(separator: ",")
        let dtos: [CharacterDTO] = try await get(baseURL.appending(path: "character/\(path)"))
        return dtos.map { $0.toDomain() }
    }

    func portrait(from url: URL) async throws -> Data {
        let data = try await send(url, accepting: "image/*")
        guard ImageValidation.isImage(data) else {
            Self.logger.error("The portrait from \(url, privacy: .public) is not an image")
            throw APIError.decoding
        }
        return data
    }

    private func get<Response: Decodable>(_ url: URL) async throws -> Response {
        let data = try await send(url, accepting: "application/json")

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

    private func send(_ url: URL, accepting contentType: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(contentType, forHTTPHeaderField: "Accept")
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
