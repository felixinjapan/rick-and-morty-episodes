#if DEBUG
import Foundation

extension FileEpisodeStore {
    /// A throwaway cache for previews.
    static let preview = FileEpisodeStore(fileURL: .temporaryDirectory.appending(path: "Previews").appending(path: FileEpisodeStore.defaultFileName))
}
#endif
