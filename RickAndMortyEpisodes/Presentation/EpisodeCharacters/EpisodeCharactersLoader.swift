import Foundation
import Observation

@MainActor
@Observable
final class EpisodeCharactersLoader {
    private(set) var characters: [Int: CharacterDetails] = [:]
    private(set) var settledIDs: Set<Int> = []

    @ObservationIgnored private var hasSettled = false
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    /// SwiftUI cancels this call when the visible IDs change. A batch already sent can finish
    /// and populate the cache while the next viewport settles.
    func load(visibleIDs: Set<Int>, from repository: any CharacterRepository) async {
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

        if let inFlight {
            await inFlight.value
        }
        guard !Task.isCancelled else { return }

        let missing = visibleIDs.filter { characters[$0] == nil }
        guard !missing.isEmpty else { return }
        let batch = Task { [weak self] in
            let loaded = await repository.characters(ids: missing.sorted())
            self?.characters.merge(loaded) { _, latest in latest }
            self?.inFlight = nil
        }
        inFlight = batch
        await batch.value
    }
}
