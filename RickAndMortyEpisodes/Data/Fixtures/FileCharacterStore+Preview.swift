#if DEBUG
import Foundation

extension FileCharacterStore {
    static func makePreview() -> FileCharacterStore {
        FileCharacterStore(directory: URL.temporaryDirectory.appending(path: "Previews/\(UUID().uuidString)/characters"))
    }
}
#endif
