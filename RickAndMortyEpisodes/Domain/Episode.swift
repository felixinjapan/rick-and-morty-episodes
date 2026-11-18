import Foundation

struct Episode: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// The day it first aired (midnight GMT), or `nil` if the API's value was missing or unreadable.
    let airDate: Date?
    let code: String
    let characterIDs: [Int]

    init(id: Int, name: String, airDate: Date?, code: String, characterIDs: [Int]) {
        self.id = id
        self.name = name
        self.airDate = airDate
        self.code = code
        var seen: Set<Int> = []
        self.characterIDs = characterIDs.filter { $0 > 0 && seen.insert($0).inserted }
    }
}
