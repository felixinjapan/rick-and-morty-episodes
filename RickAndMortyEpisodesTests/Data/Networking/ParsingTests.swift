import Foundation
import Testing
@testable import RickAndMortyEpisodes

@Suite("Parsing API values")
struct ParsingTests {
    @Test("Air dates not in the API's format are read as missing", arguments: ["", "TBA", "2013-12-02"])
    func unparseableAirDate(apiValue: String) {
        #expect(AirDateParser.date(from: apiValue) == nil)
    }

    @Test("Character IDs are parsed from resource URLs")
    func resourceIDParsing() {
        #expect(ResourceID.from("https://rickandmortyapi.com/api/character/42") == 42)
        #expect(ResourceID.from("https://rickandmortyapi.com/api/character/") == nil)
        #expect(ResourceID.from("not a url") == nil)
    }
}
