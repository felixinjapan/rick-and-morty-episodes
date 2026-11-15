#if DEBUG
import Foundation

extension FileCharacterStore {
    /// A new, empty store for each preview, so a preview never depends on what an earlier run saved.
    static func makePreview() -> FileCharacterStore {
        FileCharacterStore(directory: URL.temporaryDirectory.appending(path: "Previews/\(UUID().uuidString)/characters"))
    }
}
#endif
