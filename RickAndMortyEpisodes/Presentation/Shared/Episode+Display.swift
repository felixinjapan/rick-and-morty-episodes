import Foundation

extension Episode {
    var seasonNumber: Int? { codeNumbers?.season }

    /// "Season 1, episode 2" for S01E02, since VoiceOver would spell the code out letter by letter.
    /// Falls back to the raw code when it isn't in the SxxExx form.
    var spokenCode: String {
        guard let codeNumbers else { return code }
        return String(localized: .episodeCodeSpoken(codeNumbers.season, codeNumbers.episode))
    }

    private var codeNumbers: (season: Int, episode: Int)? {
        let parts = code.split(separator: "E", maxSplits: 1)
        guard parts.count == 2, parts[0].first == "S",
              let season = Int(parts[0].dropFirst()), season > 0,
              let episode = Int(parts[1]), episode > 0 else { return nil }
        return (season, episode)
    }

    var formattedAirDate: String {
        airDate.map(AirDateFormatter.displayString(from:)) ?? String(localized: .episodeAirDateUnknown)
    }

    var airedDateLabel: LocalizedStringResource {
        airDate == nil ? .episodeAirDateUnknown : .episodeAirDateAired(formattedAirDate)
    }
}
