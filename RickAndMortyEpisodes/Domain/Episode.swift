import Foundation

/// An episode as the app uses it. Decoupled from the API's JSON shape (see `EpisodeDTO`)
/// so the persisted cache and the UI don't break when the API adds or renames fields.
struct Episode: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    /// Raw API value, e.g. "December 2, 2013". Kept raw so the display format can change
    /// without migrating the cache.
    let airDate: String
    /// Episode code, e.g. "S01E01".
    let code: String
    let characterIDs: [Int]
}
