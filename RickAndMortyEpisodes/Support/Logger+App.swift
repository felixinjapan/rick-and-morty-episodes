import Foundation
import os

extension Logger {
    /// A logger under the app's bundle identifier, so all of the app's messages can be
    /// filtered together in Console.
    init(category: String) {
        self.init(subsystem: Bundle.main.bundleIdentifier ?? "RickAndMortyEpisodes", category: category)
    }
}
