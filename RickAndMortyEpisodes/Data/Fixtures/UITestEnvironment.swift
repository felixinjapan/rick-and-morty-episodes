#if DEBUG
import Foundation

/// What the UI-test launch arguments swap in: recorded or simulated data, and a cache of its own.
struct UITestEnvironment {
    let api: any RickAndMortyAPI
    let cacheDirectory: URL

    /// `nil` unless the app was launched with `-uiTesting`.
    init?(arguments: [String]) {
        guard arguments.contains("-uiTesting") else { return nil }
        let delayedFeed = arguments.contains("-delayedEpisodeFeed")
        let cast: DelayedEpisodeFeed.Cast = if arguments.contains("-characterEdgeCases") {
            .edgeCases
        } else if arguments.contains("-endlessCharacters") {
            .endless
        } else {
            .recorded
        }
        cacheDirectory = URL.temporaryDirectory.appending(path: delayedFeed ? cast.rawValue : "UI Testing")
        if arguments.contains("-resetCache") {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        api = if arguments.contains("-networkUnavailable") {
            UnavailableRickAndMortyAPI()
        } else if delayedFeed {
            DelayedEpisodeFeed(cast: cast)
        } else {
            LiveRickAndMortyAPI.recorded()
        }
    }
}
#endif
