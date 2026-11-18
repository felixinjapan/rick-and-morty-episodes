import Foundation
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
    func airDateFormatting(apiValue: String, expected: String) throws {
        let date = try #require(AirDateParser.date(from: apiValue))
        #expect(AirDateFormatter.displayString(from: date) == expected)
    }

    @Test("An episode code is read as a season and an episode", arguments: [
        ("S01E01", "Season 1, episode 1"),
        ("S03E10", "Season 3, episode 10"),
        ("Special", "Special"),
        ("S00E01", "S00E01"),
    ])
    func spokenCode(code: String, expected: String) {
        let episode = Episode(id: 1, name: "Pilot", airDate: nil, code: code, characterIDs: [])
        #expect(episode.spokenCode == expected)
    }

    @Test("A missing air date is shown as unknown")
    func missingAirDate() {
        let episode = Episode(id: 1, name: "Pilot", airDate: nil, code: "S01E01", characterIDs: [])
        #expect(episode.formattedAirDate == "Unknown air date")
    }
}
