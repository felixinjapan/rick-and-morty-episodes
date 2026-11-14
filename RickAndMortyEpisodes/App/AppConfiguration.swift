import Foundation

/// Values that are product or environment decisions, defined in one place.
///
/// Only the App layer reads it. The composition root passes the values down, so features
/// and data code receive plain parameters and stay testable with their own values.
struct AppConfiguration: Sendable {
    /// Base URL of the Rick and Morty API.
    var apiBaseURL: URL
    /// How long fetched episodes count as fresh. Used both for the foreground refresh check
    /// and as the earliest time for the next background refresh, so the two can't drift apart.
    var freshnessInterval: TimeInterval
    /// Short timeouts suit a small JSON API; the 60 s default would leave a spinner up too long.
    var requestTimeout: TimeInterval
    var resourceTimeout: TimeInterval

    static let production = AppConfiguration(
        apiBaseURL: URL(string: "https://rickandmortyapi.com/api")!,
        freshnessInterval: 60 * 60,
        requestTimeout: 15,
        resourceTimeout: 30
    )

    /// The configuration the app runs with. A staging environment would be chosen here,
    /// for example from the build configuration.
    static let current = production
}
