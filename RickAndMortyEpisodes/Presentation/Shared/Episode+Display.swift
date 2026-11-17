import Foundation

extension Episode {
    var formattedAirDate: String {
        airDate.map(AirDateFormatter.displayString(from:)) ?? String(localized: .episodeAirDateUnknown)
    }
}
