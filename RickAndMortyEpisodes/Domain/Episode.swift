import Foundation

/// An episode as the app uses it. Decoupled from the API's JSON shape (see `EpisodeDTO`)
/// so the persisted cache and the UI don't break when the API adds or renames fields.
struct Episode: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    /// The day the episode first aired (midnight GMT), or `nil` if the API's value couldn't
    /// be read. Formatting for display is the presentation layer's job.
    let airDate: Date?
    /// Episode code, e.g. "S01E01".
    let code: String
    let characterIDs: [Int]
}
