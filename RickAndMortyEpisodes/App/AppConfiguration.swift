import Foundation

struct AppConfiguration: Sendable {
    var apiBaseURL: URL
    /// Shared by foreground staleness checks and background scheduling.
    var freshnessInterval: TimeInterval
    /// Character details also expire when the catalogue changes size.
    var characterMaxAge: TimeInterval
    /// Short timeouts suit a small JSON API; the 60 s default would leave a spinner up too long.
    var requestTimeout: TimeInterval
    var resourceTimeout: TimeInterval

    static let production = AppConfiguration(
        apiBaseURL: URL(string: "https://rickandmortyapi.com/api")!,
        freshnessInterval: 12 * 60 * 60,
        characterMaxAge: 30 * 24 * 60 * 60,
        requestTimeout: 15,
        resourceTimeout: 30
    )
}
