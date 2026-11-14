#if DEBUG
import Foundation

extension FileEpisodeStore {
    /// A new, empty cache for each preview, so a preview never depends on what an earlier
    /// run saved.
    static func preview() -> FileEpisodeStore {
        let folder = URL.temporaryDirectory.appending(path: "Previews/\(UUID().uuidString)")
        return FileEpisodeStore(fileURL: folder.appending(path: defaultFileName))
    }
}
#endif
