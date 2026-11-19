import Foundation
import ImageIO

/// Turns saved or downloaded portrait bytes into display-sized images. Temporary failures are
/// retried once here, so callers only see the final outcome.
struct PortraitLoader {
    private let repository: any PortraitRepository
    private let maxPixelSize: Int

    /// The default fits the largest cast portrait: 80 points, or 240 pixels on a 3x display.
    init(repository: any PortraitRepository, maxPixelSize: Int = 240) {
        self.repository = repository
        self.maxPixelSize = maxPixelSize
    }

    var loadThumbnail: LoadThumbnail {
        { await thumbnail(for: $0) }
    }

    func thumbnail(for character: CharacterDetails) async -> PortraitResult? {
        switch await attempt(for: character) {
        case .finished(let result):
            return result
        case .transient(let delay):
            do {
                try await Task.sleep(for: delay)
            } catch {
                return nil
            }
            switch await attempt(for: character) {
            case .finished(let result): return result
            case .transient: return .unavailable(retryable: true)
            }
        }
    }

    private enum Attempt {
        case finished(PortraitResult?)
        case transient(delay: Duration)
    }

    private func attempt(for character: CharacterDetails) async -> Attempt {
        do {
            try Task.checkCancellation()
            let data = try await repository.portrait(for: character)
            try Task.checkCancellation()
            return .finished(
                Self.thumbnail(from: data, maxPixelSize: maxPixelSize).map(PortraitResult.image)
                    ?? .unavailable(retryable: false)
            )
        } catch is CancellationError {
            return .finished(nil)
        } catch let error as RepositoryError {
            switch PortraitFailure(error) {
            case .transient(let delay): return .transient(delay: delay)
            case .retryLater: return .finished(.unavailable(retryable: true))
            case .permanent: return .finished(.unavailable(retryable: false))
            }
        } catch {
            return .finished(.unavailable(retryable: false))
        }
    }

    private static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
