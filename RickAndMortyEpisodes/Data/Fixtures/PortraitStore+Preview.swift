#if DEBUG
import Foundation

extension PortraitStore {
    /// A new, empty store for each preview, so a preview never depends on what an earlier run saved.
    static func makePreview() -> PortraitStore {
        PortraitStore(directory: URL.temporaryDirectory.appending(path: "Previews/\(UUID().uuidString)/portraits"))
    }
}
#endif
