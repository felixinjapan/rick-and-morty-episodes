#if DEBUG
import Foundation

extension PortraitStore {
    static func makePreview() -> PortraitStore {
        PortraitStore(directory: URL.temporaryDirectory.appending(path: "Previews/\(UUID().uuidString)/portraits"))
    }
}
#endif
