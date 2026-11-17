import Foundation

struct Episode: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// The day it first aired (midnight GMT), or `nil` if the API's value was missing or unreadable.
    let airDate: Date?
    let code: String
    let characterIDs: [Int]
}
