import Foundation

/// Which portraits are worth requesting, and how many outcomes to remember. It holds no images:
/// the view layer keeps those, and drops the one for the URL that `remember` returns.
struct PortraitLoadPolicy {
    static let capacity = 128
    static let concurrentLoads = 3
    static let retryDelay: Duration = .seconds(30)

    private enum Remembered {
        case final
        case retry(after: ContinuousClock.Instant)
    }

    private var remembered: [URL: Remembered] = [:]
    private var order: [URL] = []

    func needsLoad(_ url: URL, at now: ContinuousClock.Instant) -> Bool {
        switch remembered[url] {
        case nil: true
        case .final?: false
        case .retry(let after)?: after <= now
        }
    }

    /// Remembers the outcome. Returns the URL whose outcome was dropped to make room, if any, so the
    /// view layer can drop that image too.
    @discardableResult
    mutating func remember(_ outcome: PortraitResult, for url: URL, at now: ContinuousClock.Instant) -> URL? {
        var evicted: URL?
        if remembered[url] == nil {
            if order.count == Self.capacity {
                let oldest = order.removeFirst()
                remembered[oldest] = nil
                evicted = oldest
            }
            order.append(url)
        }
        switch outcome {
        case .image:
            remembered[url] = .final
        case .unavailable(let retryable):
            remembered[url] = retryable ? .retry(after: now.advanced(by: Self.retryDelay)) : .final
        }
        return evicted
    }
}
