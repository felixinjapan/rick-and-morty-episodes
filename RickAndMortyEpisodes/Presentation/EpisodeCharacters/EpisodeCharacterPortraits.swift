import CoreGraphics
import Observation
import Foundation

/// One slot per portrait URL, so a finished portrait redraws only the rows showing it.
@MainActor
@Observable
final class PortraitSlot {
    fileprivate(set) var phase: CharacterPortraitPhase = .loading
}

@MainActor
final class EpisodeCharacterPortraits {
    private var slots: [URL: PortraitSlot] = [:]
    private var policy = PortraitLoadPolicy()

    func phase(for url: URL?) -> CharacterPortraitPhase {
        guard let url else { return .failed }
        return slot(for: url).phase
    }

    func load(for characters: [CharacterDetails], using loadThumbnail: @escaping LoadThumbnail) async {
        guard !Task.isCancelled else { return }
        var seen: Set<URL> = []
        let now = ContinuousClock.now
        var pending = characters.compactMap { character -> (URL, CharacterDetails)? in
            guard let url = character.imageURL, seen.insert(url).inserted else { return nil }
            _ = slot(for: url)
            return policy.needsLoad(url, at: now) ? (url, character) : nil
        }.makeIterator()

        await withTaskGroup(of: (URL, PortraitResult)?.self) { group in
            func addNext() {
                guard let (url, character) = pending.next() else { return }
                group.addTask { await loadThumbnail(character).map { (url, $0) } }
            }
            for _ in 0..<PortraitLoadPolicy.concurrentLoads { addNext() }
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
        // Resets the evicted slot too, so a row still showing it asks for a fresh one on its next update.
        if let evicted = policy.remember(outcome, for: url, at: .now) {
            slots.removeValue(forKey: evicted)?.phase = .loading
        }
        let slot = slot(for: url)
        switch outcome {
        case .image(let image): slot.phase = .loaded(image)
        case .unavailable: slot.phase = .failed
        }
    }
}
