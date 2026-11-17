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

    /// A small solid-colour image that stands in for every avatar.
    static let portrait = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGPQmtuPFTEMLQkAT3dVgRdrT9YAAAAASUVORK5CYII=")!

    static func character(id: Int) throws -> Data? {
        let all = try JSONSerialization.jsonObject(with: data(named: "characters")) as? [[String: Any]]
        guard let match = all?.first(where: { $0["id"] as? Int == id }) else { return nil }
        return try JSONSerialization.data(withJSONObject: match)
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
        } else if path.dropLast().last == "character", let id = Int(path.last ?? "") {
            body = try RecordedResponses.character(id: id)
        }

        let response = HTTPURLResponse(
            url: url, statusCode: body == nil ? 404 : 200, httpVersion: nil, headerFields: nil
        )!
        return (body ?? Data(#"{"error":"Not found"}"#.utf8), response)
    }
}
#endif
