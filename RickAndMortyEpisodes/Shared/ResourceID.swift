import Foundation

/// The API references related resources by URL (".../character/42").
/// The trailing path component is the resource ID.
enum ResourceID {
    static func from(_ urlString: String) -> Int? {
        guard let url = URL(string: urlString) else { return nil }
        return Int(url.lastPathComponent)
    }
}
