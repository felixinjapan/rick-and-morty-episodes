import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Image validation")
struct ImageValidationTests {
    @Test("A real image is accepted")
    func validImage() {
        #expect(ImageValidation.isImage(RecordedResponses.portrait))
    }

    @Test("Bytes that are not an image are rejected", arguments: [
        Data(),
        Data("<html>Not found</html>".utf8),
        Data("not an image".utf8),
    ])
    func notAnImage(data: Data) {
        #expect(!ImageValidation.isImage(data))
    }

    @Test("An image cut short is rejected")
    func truncatedImage() {
        #expect(!ImageValidation.isImage(RecordedResponses.portrait.prefix(30)))
    }
}
