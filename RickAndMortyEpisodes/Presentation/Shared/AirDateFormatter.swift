import Foundation

/// Converts the API's air date ("December 2, 2013") into `dd/MM/yyyy` ("02/12/2013").
///
/// Parsing uses a fixed `en_US_POSIX` locale: the API always sends English month names,
/// and parsing with the device locale would fail on, for example, a Japanese-locale device.
/// Both parsing and formatting use GMT so the day can't shift across time zones.
enum AirDateFormatter {
    private static let parseStrategy = Date.ParseStrategy(
        format: "\(month: .wide) \(day: .defaultDigits), \(year: .defaultDigits)",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .gmt,
        // Lenient parsing (the default) would also accept input that isn't in the API's format,
        // e.g. "2013-12-02", and show a wrong date instead of the raw value.
        isLenient: false
    )

    private static let displayStyle = Date.VerbatimFormatStyle(
        format: "\(day: .twoDigits)/\(month: .twoDigits)/\(year: .defaultDigits)",
        timeZone: .gmt,
        calendar: Calendar(identifier: .gregorian)
    )

    /// Returns the `dd/MM/yyyy` form, or the original string if it can't be parsed,
    /// so an unexpected API value is still shown instead of disappearing.
    static func displayString(from apiValue: String) -> String {
        guard let date = try? Date(apiValue, strategy: parseStrategy) else { return apiValue }
        return date.formatted(displayStyle)
    }
}
