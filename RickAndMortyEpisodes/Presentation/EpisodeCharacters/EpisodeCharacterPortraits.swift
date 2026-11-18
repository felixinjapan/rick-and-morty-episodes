import Observation
import UIKit

/// One slot per portrait URL, so a finished portrait redraws only the rows showing it.
@MainActor
@Observable
final class PortraitSlot {
    fileprivate(set) var phase: CharacterPortraitPhase = .loading
    @ObservationIgnored fileprivate var hasResult = false
    @ObservationIgnored fileprivate var retryAfter: ContinuousClock.Instant?
}

@MainActor
final class EpisodeCharacterPortraits {
    private static let capacity = 128
    private static let concurrentLoads = 3

    private var slots: [URL: PortraitSlot] = [:]
    private var insertionOrder: [URL] = []

    /// Reading the phase observes only this URL's slot.
    func phase(for url: URL?) -> CharacterPortraitPhase {
        guard let url else { return .failed }
        return slot(for: url).phase
    }

    func load(for characters: [CharacterDetails], using loader: any PortraitLoading) async {
        guard !Task.isCancelled else { return }
        var seen: Set<URL> = []
        let now = ContinuousClock.now
        var pending = characters.compactMap { character -> (URL, CharacterDetails)? in
            guard let url = character.imageURL, seen.insert(url).inserted else { return nil }
            let slot = slot(for: url)
            if slot.hasResult {
                guard let retryAfter = slot.retryAfter, retryAfter <= now else { return nil }
            }
            return (url, character)
        }.makeIterator()

        await withTaskGroup(of: (URL, PortraitResult)?.self) { group in
            func addNext() {
                guard let (url, character) = pending.next() else { return }
                group.addTask { await loader.thumbnail(for: character).map { (url, $0) } }
            }
            for _ in 0..<Self.concurrentLoads { addNext() }
            for await result in group {
                guard !Task.isCancelled else { return }
                addNext()
                if let (url, outcome) = result { store(outcome, for: url) }
            }
        }
    }

    private func slot(for url: URL) -> PortraitSlot {
        if let slot = slots[url] { return slot }
        let slot = PortraitSlot()
        slots[url] = slot
        return slot
    }

    private func store(_ outcome: PortraitResult, for url: URL) {
        let slot = slot(for: url)
        if !slot.hasResult {
            if insertionOrder.count == Self.capacity { evictOldest() }
            insertionOrder.append(url)
            slot.hasResult = true
        }
        switch outcome {
        case .image(let image):
            slot.phase = .loaded(UIImage(cgImage: image))
            slot.retryAfter = nil
        case .unavailable(let retryable):
            slot.phase = .failed
            slot.retryAfter = retryable ? ContinuousClock.now.advanced(by: .seconds(30)) : nil
        }
    }

    /// Resets the slot too, so a row still showing it asks for a fresh one on its next update.
    private func evictOldest() {
        let url = insertionOrder.removeFirst()
        guard let slot = slots.removeValue(forKey: url) else { return }
        slot.hasResult = false
        slot.phase = .loading
    }
}
