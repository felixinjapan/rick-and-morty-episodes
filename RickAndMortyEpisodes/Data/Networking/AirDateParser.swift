import Foundation

/// Reads the API's air date ("December 2, 2013"). The fixed `en_US_POSIX` locale matches the API's
/// English month names on any device; GMT matches `AirDateFormatter`, so the day can't shift.
enum AirDateParser {
    private static let strategy = Date.ParseStrategy(
        format: "\(month: .wide) \(day: .defaultDigits), \(year: .defaultDigits)",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .gmt,
        // Not lenient: lenient parsing accepts e.g. "2013-12-02" and returns a wrong date.
        isLenient: false
    )

    /// The date, or `nil` if the value isn't in the API's format.
    static func date(from apiValue: String) -> Date? {
        try? Date(apiValue, strategy: strategy)
    }
}
