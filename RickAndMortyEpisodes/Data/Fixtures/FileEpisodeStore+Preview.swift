#if DEBUG
import Foundation

extension FileEpisodeStore {
    static func makePreview() -> FileEpisodeStore {
        let folder = URL.temporaryDirectory.appending(path: "Previews/\(UUID().uuidString)")
        return FileEpisodeStore(fileURL: folder.appending(path: defaultFileName))
    }
}
#endif
