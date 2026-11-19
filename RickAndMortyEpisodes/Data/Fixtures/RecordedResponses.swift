#if DEBUG
import Foundation

/// Stub data: real responses saved from rickandmortyapi.com (all 51 episodes and the 826 characters
/// they reference), kept in `StubData/` so UI tests and previews run without the network.
/// The folder is in `DEVELOPMENT_ASSET_PATHS`, so archives leave it out.
enum RecordedResponses {
    static func data(named name: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }

    static let portrait = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGPQmtuPFTEMLQkAT3dVgRdrT9YAAAAASUVORK5CYII=")!

    static func characters(ids: [Int]) throws -> Data? {
        let all = try JSONSerialization.jsonObject(with: data(named: "characters")) as? [[String: Any]]
        let requested = Set(ids)
        let matches = all?.filter { character in
            (character["id"] as? Int).map(requested.contains) ?? false
        } ?? []
        guard let first = matches.first else { return nil }
        return try JSONSerialization.data(withJSONObject: ids.count == 1 ? first as Any : matches)
    }
}

extension HTTPTransport {
    static let recorded = HTTPTransport { request in
        guard let url = request.url else { throw URLError(.badURL) }
        let path = url.pathComponents
        let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "page" }?.value

        var body: Data?
        if path.last == "episode", let page {
            body = try? RecordedResponses.data(named: "episodes-page-\(page)")
        } else if path.dropLast().last == "avatar" {
            body = RecordedResponses.portrait
        } else if path.dropLast().last == "character", let ids = path.last {
            body = try RecordedResponses.characters(ids: ids.split(separator: ",").compactMap { Int($0) })
        }

        let response = HTTPURLResponse(
            url: url, statusCode: body == nil ? 404 : 200, httpVersion: nil, headerFields: nil
        )!
        return (body ?? Data(#"{"error":"Not found"}"#.utf8), response)
    }
}
#endif
