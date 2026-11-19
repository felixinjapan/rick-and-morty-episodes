import Foundation
import Observation

@MainActor
@Observable
final class EpisodeCharactersViewModel {
    let portraits = EpisodeCharacterPortraits()
    private(set) var characters: [Int: CharacterDetails] = [:]
    /// The visible IDs once scrolling paused. No view reads it; tests wait on it.
    private(set) var settledIDs: Set<Int> = []
    private(set) var unavailableIDs: Set<Int> = []

    /// The first request is small so the first screen fills quickly; later ones are bigger. A request
    /// is capped at `chunkSize` IDs, which keeps the URL and the response small for any cast.
    private static let firstChunkSize = 20
    private static let chunkSize = 80
    /// The next chunk is requested once a visible row is this far through the chunk holding it.
    private static let prefetchFraction = 0.8

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

    /// Loads what the visible rows need first, then their portraits, then the next chunk, so a
    /// prefetch never holds up what is on screen.
    func loadVisibleCast(visibleIDs: Set<Int>) async {
        guard await settle(on: visibleIDs) else { return }
        let plan = chunks(for: visibleIDs)
        await loadCharacters(in: plan.held, visibleIDs: visibleIDs)
        guard !Task.isCancelled else { return }
        let nearby = nearbyIDs(for: visibleIDs, padding: 2).subtracting(visibleIDs)
        let portraitIDs = visibleIDs.sorted() + nearby.sorted()
        await portraits.load(for: portraitIDs.compactMap { characters[$0] }, using: portraitLoader)
        guard !Task.isCancelled else { return }
        await loadCharacters(in: plan.prefetch, visibleIDs: visibleIDs)
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

    /// Returns whether to go on loading for these rows. SwiftUI cancels the call when the visible IDs
    /// change, so only the last viewport of a scroll gets past the sleep. A batch already sent can
    /// finish and populate the cache while the next viewport settles.
    private func settle(on visibleIDs: Set<Int>) async -> Bool {
        guard !Task.isCancelled else { return false }
        guard !visibleIDs.isEmpty else {
            settledIDs = []
            return false
        }

        // Coalesce the initial layout callbacks without making the first screen wait for a scroll.
        do {
            try await Task.sleep(for: hasSettled ? .milliseconds(200) : .milliseconds(35))
        } catch {
            return false
        }
        guard !Task.isCancelled else { return false }
        hasSettled = true
        settledIDs = visibleIDs
        return true
    }

    private func loadCharacters(in chunks: [Range<Int>], visibleIDs: Set<Int>) async {
        for chunk in chunks {
            await waitForInFlightBatch()
            guard !Task.isCancelled else { return }
            let missing = characterIDs[chunk].filter {
                characters[$0] == nil && (visibleIDs.contains($0) || !unavailableIDs.contains($0))
            }
            guard !missing.isEmpty else { continue }
            await load(missing)
        }
    }

    /// The chunk of the cast that holds the row at `index`: the first `firstChunkSize` rows, then
    /// `chunkSize` rows each.
    private func chunk(at index: Int) -> Range<Int> {
        if index < Self.firstChunkSize { return 0..<min(characterIDs.count, Self.firstChunkSize) }
        let start = Self.firstChunkSize + (index - Self.firstChunkSize) / Self.chunkSize * Self.chunkSize
        return start..<min(characterIDs.count, start + Self.chunkSize)
    }

    /// The chunks to load for these rows: the ones holding them, and the next one when a row is far
    /// enough through its chunk. The first chunk always brings the second, so a short cast is
    /// complete after two requests. A jump far down the list loads the chunk around the destination,
    /// not every chunk in between.
    private func chunks(for visibleIDs: Set<Int>) -> (held: [Range<Int>], prefetch: [Range<Int>]) {
        let rows = Dictionary(grouping: visibleIDs.compactMap { indices[$0] }, by: chunk(at:))
        let held = rows.keys.sorted { $0.lowerBound < $1.lowerBound }
        var next: [Range<Int>] = []
        for range in held {
            guard let last = rows[range]?.max() else { continue }
            if range.lowerBound == 0 || Double(last - range.lowerBound) >= Double(range.count) * Self.prefetchFraction {
                next.append(chunk(at: range.upperBound))
            }
        }
        var seen = Set(held)
        return (held, next.filter { !$0.isEmpty && seen.insert($0).inserted })
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
