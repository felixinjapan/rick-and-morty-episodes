import Foundation

/// An episode as the app uses it. The API's JSON (`EpisodeDTO`) and the cache file
/// (`CachedEpisodeSnapshot`) each have their own types, so neither can change this one.
struct Episode: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// The day the episode first aired (midnight GMT), or `nil` if the API's value couldn't
    /// be read. Formatting for display is the presentation layer's job.
    let airDate: Date?
    /// Episode code, e.g. "S01E01".
    let code: String
    let characterIDs: [Int]
}
