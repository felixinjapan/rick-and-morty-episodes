import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class EpisodeCharacterPortraits {
    private struct Entry {
        let phase: CharacterPortraitPhase
        let retryAfter: ContinuousClock.Instant?
    }

    private var results: [URL: Entry] = [:]
    @ObservationIgnored private var insertionOrder: [URL] = []
    private let capacity = 128

    func phase(for url: URL?) -> CharacterPortraitPhase {
        guard let url else { return .failed }
        return results[url]?.phase ?? .loading
    }

    func load(for characters: [CharacterDetails], from repository: any CharacterRepository) async {
        guard !Task.isCancelled else { return }
        var seen: Set<URL> = []
        let now = ContinuousClock.now
        var pending = characters.compactMap { character -> (URL, CharacterDetails)? in
            guard let url = character.imageURL, seen.insert(url).inserted else { return nil }
            if let entry = results[url] {
                guard let retryAfter = entry.retryAfter, retryAfter <= now else { return nil }
            }
            return (url, character)
        }.makeIterator()

        await withTaskGroup(of: (URL, CGImage?, retryable: Bool)?.self) { group in
            for _ in 0..<3 {
                guard let (url, character) = pending.next() else { break }
                group.addTask { await Self.fetch(url: url, character: character, from: repository) }
            }
            for await result in group {
                guard !Task.isCancelled else { return }
                if let (url, character) = pending.next() {
                    group.addTask { await Self.fetch(url: url, character: character, from: repository) }
                }
                guard let (url, image, retryable) = result else { continue }
                if results[url] == nil {
                    if insertionOrder.count == capacity {
                        results.removeValue(forKey: insertionOrder.removeFirst())
                    }
                    insertionOrder.append(url)
                }
                results[url] = Entry(
                    phase: image.map { .loaded(UIImage(cgImage: $0)) } ?? .failed,
                    retryAfter: retryable ? ContinuousClock.now.advanced(by: .seconds(30)) : nil
                )
            }
        }
    }

    private nonisolated static func fetch(
        url: URL, character: CharacterDetails, from repository: any CharacterRepository
    ) async -> (URL, CGImage?, retryable: Bool)? {
        for attempt in 0...1 {
            do {
                try Task.checkCancellation()
                let data = try await repository.portrait(for: character)
                try Task.checkCancellation()
                return (url, thumbnail(from: data), false)
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
                    return (url, nil, true)
                case .offline, .failed:
                    return (url, nil, true)
                case .notFound, .unreadableData:
                    return (url, nil, false)
                }
            } catch {
                return (url, nil, false)
            }
        }
        return nil
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
