#if DEBUG
import Foundation

extension CharacterExporter {
    /// Exports from previews go to a temporary folder.
    static let preview = CharacterExporter(directory: .temporaryDirectory.appending(path: "Previews/Exports"))
}
#endif
