import Foundation

/// Product and environment values selected by the composition root and passed into dependencies.
struct AppConfiguration: Sendable {
    var apiBaseURL: URL
    /// How long fetched episodes count as fresh: the foreground staleness check and the earliest
    /// background refresh both use it, so they can't drift apart. The catalogue rarely changes and a
    /// refresh is one request that also reports whether it grew, so half a day is enough.
    var freshnessInterval: TimeInterval
    /// How long saved character details are used before they are fetched again (they are also fetched
    /// again when the catalogue changes size).
    var characterMaxAge: TimeInterval
    /// Short timeouts suit a small JSON API; the 60 s default would leave a spinner up too long.
    var requestTimeout: TimeInterval
    var resourceTimeout: TimeInterval

    /// A preset value, explicitly selected at app and preview entry points.
    static let production = AppConfiguration(
        apiBaseURL: URL(string: "https://rickandmortyapi.com/api")!,
        freshnessInterval: 12 * 60 * 60,
        characterMaxAge: 30 * 24 * 60 * 60,
        requestTimeout: 15,
        resourceTimeout: 30
    )
}
