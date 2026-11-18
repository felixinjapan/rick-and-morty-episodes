import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class EpisodeCharacterPortraits {
    private var results: [URL: CharacterPortraitPhase] = [:]
    @ObservationIgnored private var insertionOrder: [URL] = []
    private let capacity = 128

    func phase(for url: URL?) -> CharacterPortraitPhase {
        guard let url else { return .failed }
        return results[url] ?? .loading
    }

    func load(for characters: [CharacterDetails], from repository: any CharacterRepository) async {
        guard !Task.isCancelled else { return }
        var seen: Set<URL> = []
        await withTaskGroup(of: (URL, CGImage?)?.self) { group in
            for character in characters {
                guard let url = character.imageURL, results[url] == nil, seen.insert(url).inserted else { continue }
                group.addTask {
                    do {
                        let data = try await repository.portrait(for: character)
                        try Task.checkCancellation()
                        return (url, Self.thumbnail(from: data))
                    } catch is CancellationError {
                        return nil
                    } catch {
                        return (url, nil)
                    }
                }
            }
            for await result in group {
                guard !Task.isCancelled, let (url, image) = result else { continue }
                if results[url] == nil {
                    if insertionOrder.count == capacity {
                        results.removeValue(forKey: insertionOrder.removeFirst())
                    }
                    insertionOrder.append(url)
                }
                results[url] = image.map { .loaded(UIImage(cgImage: $0)) } ?? .failed
            }
        }
    }

    private nonisolated static func thumbnail(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // Cast portraits are at most 80 points, or 240 pixels on a 3x display.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 240
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
