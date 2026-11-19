import CoreGraphics
import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Portrait loader")
struct PortraitLoaderTests {
    private static let avatar = CharacterDetails.rick.imageURL!

    @Test("A downloaded portrait is decoded to at most the requested size")
    func decodesThumbnail() async throws {
        let api = StubAPI(portraits: [Self.avatar: .success(RecordedResponses.portrait)])
        let loader = PortraitLoader(repository: DefaultPortraitRepository.makeTemporary(api: api), maxPixelSize: 16)

        guard case .image(let image)? = await loader.thumbnail(for: .rick) else {
            Issue.record("Expected a decoded image")
            return
        }
        #expect(max(image.width, image.height) <= 16)
    }

    @Test("A missing portrait is unavailable and not worth retrying")
    func missingPortrait() async {
        let loader = PortraitLoader(repository: DefaultPortraitRepository.makeTemporary(api: StubAPI()))

        guard case .unavailable(let retryable)? = await loader.thumbnail(for: .rick) else {
            Issue.record("Expected an unavailable portrait")
            return
        }
        #expect(!retryable)
    }

    @Test("A cancelled load reports nothing")
    func cancelled() async {
        let loader = PortraitLoader(repository: DefaultPortraitRepository.makeTemporary(api: StubAPI()))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await loader.thumbnail(for: .rick)
        }

        #expect(await task.value == nil)
    }
}
