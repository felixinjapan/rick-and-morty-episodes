import Foundation

/// An episode as the app uses it. The API's JSON and the cache file have their own types.
struct Episode: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// The day it first aired (midnight GMT), or `nil` if the API's value was missing or unreadable.
    let airDate: Date?
    /// Episode code, e.g. "S01E01".
    let code: String
    let characterIDs: [Int]
}
