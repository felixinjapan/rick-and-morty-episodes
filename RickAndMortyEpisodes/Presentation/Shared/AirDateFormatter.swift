import Foundation

/// GMT matches AirDateParser so device time zones cannot shift the displayed day.
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
