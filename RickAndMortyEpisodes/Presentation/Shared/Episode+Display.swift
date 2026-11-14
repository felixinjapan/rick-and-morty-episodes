import Foundation

extension Episode {
    /// Air date in the `dd/MM/yyyy` format required by the assignment. A display concern,
    /// so it lives in the presentation layer rather than on the domain entity.
    var formattedAirDate: String { AirDateFormatter.displayString(from: airDate) }
}
