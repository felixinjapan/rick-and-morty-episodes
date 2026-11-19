import CoreTransferable
import UniformTypeIdentifiers

/// The character's export file for the share sheet. It is written when the user picks a
/// destination, not when they tap the export button, so nothing is saved until they choose to.
struct CharacterExportFile: Transferable, Sendable {
    let title: String
    let write: @Sendable () throws -> URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            SentTransferredFile(try file.write(), allowAccessingOriginalFile: false)
        }
    }
}
