import Foundation

enum ResourceID {
    static func from(_ urlString: String) -> Int? {
        guard let url = URL(string: urlString) else { return nil }
        return Int(url.lastPathComponent)
    }
}
