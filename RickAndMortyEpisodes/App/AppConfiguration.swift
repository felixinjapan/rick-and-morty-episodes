import Foundation

struct AppConfiguration: Sendable {
    let apiBaseURL: URL
    /// Shared by foreground staleness checks and background scheduling.
    let freshnessInterval: TimeInterval
    /// Character details also expire when the catalogue changes size.
    let characterMaxAge: TimeInterval
    /// Short timeouts suit a small JSON API; the 60 s default would leave a spinner up too long.
    let requestTimeout: TimeInterval
    let resourceTimeout: TimeInterval

    static let production = AppConfiguration(
        apiBaseURL: URL(string: "https://rickandmortyapi.com/api")!,
        freshnessInterval: 12 * 60 * 60,
        characterMaxAge: 30 * 24 * 60 * 60,
        requestTimeout: 15,
        resourceTimeout: 30
    )
}
