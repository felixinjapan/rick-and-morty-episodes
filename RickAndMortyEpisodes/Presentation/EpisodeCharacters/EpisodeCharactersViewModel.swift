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

        for chunk in chunks(for: visibleIDs) {
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

    /// The chunks to load for these rows, in order: the ones holding them, then the next one when a
    /// row is far enough through its chunk. The first chunk always brings the second, so a short
    /// cast is complete after two requests. A jump far down the list loads the chunk around the
    /// destination, not every chunk in between.
    private func chunks(for visibleIDs: Set<Int>) -> [Range<Int>] {
        let rows = Dictionary(grouping: visibleIDs.compactMap { indices[$0] }, by: chunk(at:))
        let held = rows.keys.sorted { $0.lowerBound < $1.lowerBound }
        var wanted = held
        for range in held {
            guard let last = rows[range]?.max() else { continue }
            if range.lowerBound == 0 || Double(last - range.lowerBound) >= Double(range.count) * Self.prefetchFraction {
                wanted.append(chunk(at: range.upperBound))
            }
        }
        var seen: Set<Range<Int>> = []
        return wanted.filter { !$0.isEmpty && seen.insert($0).inserted }
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
