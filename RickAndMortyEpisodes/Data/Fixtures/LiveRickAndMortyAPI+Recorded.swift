#if DEBUG
import Foundation

extension LiveRickAndMortyAPI {
    static func recorded() -> LiveRickAndMortyAPI {
        LiveRickAndMortyAPI(
            baseURL: URL(string: "https://recorded.invalid/api")!,
            transport: .recorded
        )
    }
}
#endif
