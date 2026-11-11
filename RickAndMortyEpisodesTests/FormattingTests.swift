import Testing
@testable import RickAndMortyEpisodes

@Suite("Formatting")
struct FormattingTests {
    @Test("Air date is shown as dd/MM/yyyy", arguments: [
        ("December 2, 2013", "02/12/2013"),
        ("April 7, 2014", "07/04/2014"),
        ("September 10, 2017", "10/09/2017"),
        ("January 31, 2021", "31/01/2021"),
    ])
    func airDateFormatting(apiValue: String, expected: String) {
        #expect(AirDateFormatter.displayString(from: apiValue) == expected)
    }

    @Test("Unparseable air dates are shown unchanged", arguments: ["", "TBA", "2013-12-02"])
    func unparseableAirDate(apiValue: String) {
        #expect(AirDateFormatter.displayString(from: apiValue) == apiValue)
    }

    @Test("Character IDs are parsed from resource URLs")
    func resourceIDParsing() {
        #expect(ResourceID.from("https://rickandmortyapi.com/api/character/42") == 42)
        #expect(ResourceID.from("https://rickandmortyapi.com/api/character/") == nil)
        #expect(ResourceID.from("not a url") == nil)
    }
}
