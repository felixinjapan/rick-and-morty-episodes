import Foundation

extension Episode {
    var seasonNumber: Int? {
        let parts = code.split(separator: "E", maxSplits: 1)
        guard parts.count == 2, parts[0].first == "S",
              let season = Int(parts[0].dropFirst()), season > 0,
              let episode = Int(parts[1]), episode > 0 else { return nil }
        return season
    }

    var formattedAirDate: String {
        airDate.map(AirDateFormatter.displayString(from:)) ?? String(localized: .episodeAirDateUnknown)
    }

    var airedDateLabel: LocalizedStringResource {
        airDate == nil ? .episodeAirDateUnknown : .episodeAirDateAired(formattedAirDate)
    }
}
