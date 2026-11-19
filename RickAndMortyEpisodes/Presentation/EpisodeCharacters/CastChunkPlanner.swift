import Foundation

/// Decides which characters of a cast to request. The first request is small so the first screen
/// fills quickly; later ones are bigger. A request is capped at `chunkSize` IDs, which keeps the URL
/// and the response small for any cast.
struct CastChunkPlanner {
    static let firstChunkSize = 20
    static let chunkSize = 80
    /// The next chunk is requested once a visible row is this far through the chunk holding it.
    static let prefetchFraction = 0.8

    private let characterIDs: [Int]
    private let indices: [Int: Int]

    init(characterIDs: [Int]) {
        self.characterIDs = characterIDs
        indices = Dictionary(uniqueKeysWithValues: characterIDs.enumerated().map { ($0.element, $0.offset) })
    }

    func ids(in chunk: Range<Int>) -> ArraySlice<Int> {
        characterIDs[chunk]
    }

    /// The visible IDs plus the IDs within `padding` rows of them.
    func nearbyIDs(for visibleIDs: Set<Int>, padding: Int) -> Set<Int> {
        var nearby = visibleIDs
        for id in visibleIDs {
            guard let index = indices[id] else { continue }
            let start = max(0, index - padding)
            let end = min(characterIDs.count, index + padding + 1)
            nearby.formUnion(characterIDs[start..<end])
        }
        return nearby
    }

    /// The chunk of the cast that holds the row at `index`: the first `firstChunkSize` rows, then
    /// `chunkSize` rows each.
    func chunk(at index: Int) -> Range<Int> {
        if index < Self.firstChunkSize { return 0..<min(characterIDs.count, Self.firstChunkSize) }
        let start = Self.firstChunkSize + (index - Self.firstChunkSize) / Self.chunkSize * Self.chunkSize
        return start..<min(characterIDs.count, start + Self.chunkSize)
    }

    /// The chunks to load for these rows: the ones holding them, and the next one when a row is far
    /// enough through its chunk. The first chunk always brings the second, so a short cast is
    /// complete after two requests. A jump far down the list loads the chunk around the destination,
    /// not every chunk in between.
    func chunks(for visibleIDs: Set<Int>) -> (held: [Range<Int>], prefetch: [Range<Int>]) {
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
}
