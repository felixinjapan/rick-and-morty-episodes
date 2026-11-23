import Foundation

/// The size of the episode catalogue as the app last saw it. Saved character details depend on it,
/// because a new episode changes the episode counts of its characters.
protocol EpisodeCatalogue: Sendable {
    /// `nil` until an episode list has been loaded or saved.
    func knownEpisodeCount() async -> Int?
}
