import Foundation

enum ResourceID {
    static func from(_ urlString: String) -> Int? {
        URL(string: urlString).flatMap { Int($0.lastPathComponent) }
    }
}
