import Foundation

/// Shows an air date as `dd/MM/yyyy` ("02/12/2013").
/// Formats in GMT, matching how `AirDateParser` reads the API's dates, so the day can't shift.
enum AirDateFormatter {
    private static let displayStyle = Date.VerbatimFormatStyle(
        format: "\(day: .twoDigits)/\(month: .twoDigits)/\(year: .defaultDigits)",
        timeZone: .gmt,
        calendar: Calendar(identifier: .gregorian)
    )

    static func displayString(from date: Date) -> String {
        date.formatted(displayStyle)
    }
}
