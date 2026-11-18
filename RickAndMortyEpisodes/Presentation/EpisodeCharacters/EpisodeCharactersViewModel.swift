import Foundation
import Observation

@MainActor
@Observable
final class EpisodeCharactersViewModel {
    let portraits = EpisodeCharacterPortraits()
    private(set) var characters: [Int: CharacterDetails] = [:]
    private(set) var settledIDs: Set<Int> = []
    private(set) var unavailableIDs: Set<Int> = []

    @ObservationIgnored private var hasSettled = false
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    @ObservationIgnored private var batchCount = 0
    private let characterIDs: [Int]
    private let indices: [Int: Int]
    private let repository: any CharacterRepository
    private let portraitLoader: any PortraitLoading

    init(
        characterIDs: [Int] = [], repository: any CharacterRepository, portraitLoader: any PortraitLoading
    ) {
        self.characterIDs = characterIDs
        self.repository = repository
        self.portraitLoader = portraitLoader
        indices = Dictionary(uniqueKeysWithValues: characterIDs.enumerated().map { ($0.element, $0.offset) })
    }

    func loadVisibleCast(visibleIDs: Set<Int>) async {
        await loadCharacters(visibleIDs: visibleIDs)
        guard !Task.isCancelled else { return }
        let nearby = nearbyIDs(for: visibleIDs, padding: 2).subtracting(visibleIDs)
        let portraitIDs = visibleIDs.sorted() + nearby.sorted()
        await portraits.load(for: portraitIDs.compactMap { characters[$0] }, using: portraitLoader)
    }

    private func nearbyIDs(for visibleIDs: Set<Int>, padding: Int) -> Set<Int> {
        var nearby = visibleIDs
        for id in visibleIDs {
            guard let index = indices[id] else { continue }
            let start = max(0, index - padding)
            let end = min(characterIDs.count, index + padding + 1)
            nearby.formUnion(characterIDs[start..<end])
        }
        return nearby
    }

    func character(id: Int) async throws -> CharacterDetails {
        if let character = characters[id] { return character }
        await waitForInFlightBatch()
        try Task.checkCancellation()
        if let character = characters[id] { return character }
        let character = try await repository.character(id: id)
        characters[id] = character
        unavailableIDs.remove(id)
        return character
    }

    /// SwiftUI cancels this call when the visible IDs change. A batch already sent can finish
    /// and populate the cache while the next viewport settles.
    private func loadCharacters(visibleIDs: Set<Int>) async {
        guard !Task.isCancelled else { return }
        guard !visibleIDs.isEmpty else {
            settledIDs = []
            return
        }

        // Coalesce the initial layout callbacks without making the first screen wait for a scroll.
        do {
            try await Task.sleep(for: hasSettled ? .milliseconds(200) : .milliseconds(35))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        hasSettled = true
        settledIDs = visibleIDs

        await waitForInFlightBatch()
        guard !Task.isCancelled else { return }

        let missing = nearbyIDs(for: visibleIDs, padding: 6).filter {
            characters[$0] == nil && (visibleIDs.contains($0) || !unavailableIDs.contains($0))
        }
        guard !missing.isEmpty else { return }
        unavailableIDs.subtract(missing)
        batchCount += 1
        let batchNumber = batchCount
        let batch = Task { [weak self, repository] in
            let loaded = await repository.characters(ids: missing.sorted())
            guard let self else { return }
            characters.merge(loaded) { _, latest in latest }
            unavailableIDs.formUnion(missing.subtracting(loaded.keys))
            // Only the newest batch may clear the slot; an older one must not hide a running one.
            if batchCount == batchNumber { inFlight = nil }
        }
        inFlight = batch
        await batch.value
    }

    /// Waits until no batch is running. Looping covers a batch that another caller starts while
    /// this one was suspended.
    private func waitForInFlightBatch() async {
        while let batch = inFlight {
            await batch.value
            guard !Task.isCancelled else { return }
        }
    }
}
