import Foundation

/// Reads the API's air date ("December 2, 2013").
///
/// Uses a fixed `en_US_POSIX` locale: the API always sends English month names, and parsing
/// with the device locale would fail on, for example, a Japanese-locale device. Parses in GMT;
/// the display side formats in GMT too, so the day can't shift across time zones.
enum AirDateParser {
    private static let strategy = Date.ParseStrategy(
        format: "\(month: .wide) \(day: .defaultDigits), \(year: .defaultDigits)",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .gmt,
        // Lenient parsing (the default) would also accept input that isn't in the API's format,
        // e.g. "2013-12-02", and produce a wrong date instead of none.
        isLenient: false
    )

    /// The date, or `nil` if the value isn't in the API's format.
    static func date(from apiValue: String) -> Date? {
        try? Date(apiValue, strategy: strategy)
    }
}
