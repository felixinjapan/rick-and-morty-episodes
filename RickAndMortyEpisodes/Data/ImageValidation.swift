import Foundation
import ImageIO

/// Whether bytes are an image that can be decoded. Checked before a portrait is saved, and again
/// before a saved one is used, so a damaged file is replaced instead of shown as a placeholder forever.
enum ImageValidation {
    static func isImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            return false
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    }
}
