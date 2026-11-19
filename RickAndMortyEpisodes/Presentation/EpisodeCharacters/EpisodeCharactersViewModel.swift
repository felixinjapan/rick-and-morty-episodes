import Foundation
import Observation

@MainActor
@Observable
final class EpisodeCharactersViewModel {
    let portraits = EpisodeCharacterPortraits()
    private(set) var characters: [Int: CharacterDetails] = [:]
    private(set) var unavailableIDs: Set<Int> = []

    @ObservationIgnored private var hasSettled = false
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    @ObservationIgnored private var batchCount = 0
    private let planner: CastChunkPlanner
    private let repository: any CharacterRepository
    private let loadThumbnail: LoadThumbnail
    /// Waits out the debounce; tests pass one that returns at once.
    private let sleep: @Sendable (Duration) async throws -> Void

    init(
        characterIDs: [Int] = [], repository: any CharacterRepository, loadThumbnail: @escaping LoadThumbnail,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        planner = CastChunkPlanner(characterIDs: characterIDs)
        self.repository = repository
        self.loadThumbnail = loadThumbnail
        self.sleep = sleep
    }

    /// Loads what the visible rows need first, then their portraits, then the next chunk, so a
    /// prefetch never holds up what is on screen.
    func loadVisibleCast(visibleIDs: Set<Int>) async {
        guard await settle(on: visibleIDs) else { return }
        let plan = planner.chunks(for: visibleIDs)
        await loadCharacters(in: plan.held, visibleIDs: visibleIDs)
        guard !Task.isCancelled else { return }
        let nearby = planner.nearbyIDs(for: visibleIDs, padding: 2).subtracting(visibleIDs)
        let portraitIDs = visibleIDs.sorted() + nearby.sorted()
        await portraits.load(for: portraitIDs.compactMap { characters[$0] }, using: loadThumbnail)
        guard !Task.isCancelled else { return }
        await loadCharacters(in: plan.prefetch, visibleIDs: visibleIDs)
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

    /// Returns whether to go on loading for these rows. SwiftUI cancels the call when the visible IDs
    /// change, so only the last viewport of a scroll gets past the sleep. A batch already sent can
    /// finish and populate the cache while the next viewport settles.
    private func settle(on visibleIDs: Set<Int>) async -> Bool {
        guard !Task.isCancelled else { return false }
        guard !visibleIDs.isEmpty else { return false }

        // Coalesce the initial layout callbacks without making the first screen wait for a scroll.
        do {
            try await sleep(hasSettled ? .milliseconds(200) : .milliseconds(35))
        } catch {
            return false
        }
        guard !Task.isCancelled else { return false }
        hasSettled = true
        return true
    }

    private func loadCharacters(in chunks: [Range<Int>], visibleIDs: Set<Int>) async {
        for chunk in chunks {
            await waitForInFlightBatch()
            guard !Task.isCancelled else { return }
            let missing = planner.ids(in: chunk).filter {
                characters[$0] == nil && (visibleIDs.contains($0) || !unavailableIDs.contains($0))
            }
            guard !missing.isEmpty else { continue }
            await load(missing)
        }
    }

    private func load(_ missing: [Int]) async {
        unavailableIDs.subtract(missing)
        batchCount += 1
        let batchNumber = batchCount
        let batch = Task { [weak self, repository] in
            let loaded = await repository.characters(ids: missing)
            guard let self else { return }
            characters.merge(loaded) { _, latest in latest }
            unavailableIDs.formUnion(Set(missing).subtracting(loaded.keys))
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
