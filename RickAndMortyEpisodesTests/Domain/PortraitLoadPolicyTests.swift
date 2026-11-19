import CoreGraphics
import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Portrait load policy")
struct PortraitLoadPolicyTests {
    private let start = ContinuousClock.now
    private let image: PortraitResult = .image(
        CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!.makeImage()!
    )

    private func url(_ number: Int) -> URL {
        URL(string: "https://example.com/avatar/\(number).jpeg")!
    }

    @Test("A portrait nobody has loaded needs a load")
    func unseen() {
        #expect(PortraitLoadPolicy().needsLoad(url(1), at: start))
    }

    @Test("A loaded portrait is never requested again")
    func loaded() {
        var policy = PortraitLoadPolicy()
        policy.remember(image, for: url(1), at: start)

        #expect(!policy.needsLoad(url(1), at: start.advanced(by: .seconds(3600))))
    }

    @Test("A portrait that can't be loaded and isn't worth retrying is never requested again")
    func permanentFailure() {
        var policy = PortraitLoadPolicy()
        policy.remember(.unavailable(retryable: false), for: url(1), at: start)

        #expect(!policy.needsLoad(url(1), at: start.advanced(by: .seconds(3600))))
    }

    @Test("A temporary failure is retried only after the delay")
    func temporaryFailure() {
        var policy = PortraitLoadPolicy()
        policy.remember(.unavailable(retryable: true), for: url(1), at: start)

        #expect(!policy.needsLoad(url(1), at: start))
        #expect(!policy.needsLoad(url(1), at: start.advanced(by: .seconds(29))))
        #expect(policy.needsLoad(url(1), at: start.advanced(by: .seconds(30))))
    }

    @Test("A retry that succeeds is final")
    func retrySucceeds() {
        var policy = PortraitLoadPolicy()
        policy.remember(.unavailable(retryable: true), for: url(1), at: start)
        policy.remember(image, for: url(1), at: start.advanced(by: .seconds(31)))

        #expect(!policy.needsLoad(url(1), at: start.advanced(by: .seconds(3600))))
    }

    @Test("Remembering one URL again never evicts anything")
    func sameURLAgain() {
        var policy = PortraitLoadPolicy()
        for _ in 0..<(PortraitLoadPolicy.capacity * 2) {
            #expect(policy.remember(.unavailable(retryable: true), for: url(1), at: start) == nil)
        }
    }

    @Test("Past capacity the oldest outcome is dropped, and that portrait needs a load again")
    func eviction() {
        var policy = PortraitLoadPolicy()
        for number in 1...PortraitLoadPolicy.capacity {
            #expect(policy.remember(image, for: url(number), at: start) == nil)
        }

        let evicted = policy.remember(image, for: url(1_000), at: start)

        #expect(evicted == url(1))
        #expect(policy.needsLoad(url(1), at: start))
        #expect(!policy.needsLoad(url(2), at: start))
        #expect(!policy.needsLoad(url(1_000), at: start))
    }

    @Test("Eviction follows the order outcomes were first remembered, not how often a URL is updated")
    func evictionOrder() {
        var policy = PortraitLoadPolicy()
        for number in 1...PortraitLoadPolicy.capacity {
            policy.remember(.unavailable(retryable: true), for: url(number), at: start)
        }
        policy.remember(image, for: url(1), at: start.advanced(by: .seconds(60)))

        #expect(policy.remember(image, for: url(1_000), at: start) == url(1))
        #expect(policy.remember(image, for: url(1_001), at: start) == url(2))
    }

    @Test("Concurrency and capacity limits are the ones the rows were tuned for")
    func limits() {
        #expect(PortraitLoadPolicy.concurrentLoads == 3)
        #expect(PortraitLoadPolicy.capacity == 128)
        #expect(PortraitLoadPolicy.retryDelay == .seconds(30))
    }
}
