import Foundation
import ImageIO

/// Turns saved or downloaded portrait bytes into display-sized images. Temporary failures are
/// retried once here, so callers only see the final outcome.
struct PortraitLoader: PortraitLoading {
    private let repository: any CharacterRepository
    private let maxPixelSize: Int

    /// The default fits the largest cast portrait: 80 points, or 240 pixels on a 3x display.
    init(repository: any CharacterRepository, maxPixelSize: Int = 240) {
        self.repository = repository
        self.maxPixelSize = maxPixelSize
    }

    func thumbnail(for character: CharacterDetails) async -> PortraitResult? {
        for attempt in 0...1 {
            do {
                try Task.checkCancellation()
                let data = try await repository.portrait(for: character)
                try Task.checkCancellation()
                return Self.thumbnail(from: data, maxPixelSize: maxPixelSize).map(PortraitResult.image)
                    ?? .unavailable(retryable: false)
            } catch is CancellationError {
                return nil
            } catch let error as RepositoryError {
                switch error {
                case .timedOut, .rateLimited, .serverUnavailable:
                    if attempt == 0 {
                        do {
                            try await Task.sleep(for: error == .rateLimited ? .seconds(2) : .milliseconds(500))
                        } catch {
                            return nil
                        }
                        continue
                    }
                    return .unavailable(retryable: true)
                case .offline, .failed:
                    return .unavailable(retryable: true)
                case .notFound, .unreadableData:
                    return .unavailable(retryable: false)
                }
            } catch {
                return .unavailable(retryable: false)
            }
        }
        return nil
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
