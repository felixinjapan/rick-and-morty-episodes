#if DEBUG
import Foundation

struct UITestEnvironment {
    let api: any RickAndMortyAPI
    let cacheDirectory: URL

    init?(arguments: [String]) {
        guard arguments.contains("-uiTesting") else { return nil }
        let delayedFeed = arguments.contains("-delayedEpisodeFeed")
        let emptyCatalogue = arguments.contains("-emptyCatalogue")
        let cast: DelayedEpisodeFeed.Cast = if arguments.contains("-characterEdgeCases") {
            .edgeCases
        } else if arguments.contains("-endlessCharacters") {
            .endless
        } else {
            .recorded
        }
        let cacheName = if delayedFeed { cast.rawValue } else if emptyCatalogue { "Empty Catalogue" } else { "UI Testing" }
        cacheDirectory = URL.temporaryDirectory.appending(path: cacheName)
        if arguments.contains("-resetCache") {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        api = if arguments.contains("-networkUnavailable") {
            UnavailableRickAndMortyAPI()
        } else if emptyCatalogue {
            EmptyRickAndMortyAPI()
        } else if delayedFeed {
            DelayedEpisodeFeed(cast: cast)
        } else {
            LiveRickAndMortyAPI.recorded()
        }
    }
}
#endif
