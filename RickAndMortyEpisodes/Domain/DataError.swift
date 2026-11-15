import Foundation

/// What can go wrong when loading data. The Data layer translates network errors into these
/// cases; the Presentation layer words them for the user.
enum DataError: Error, Equatable {
    /// No internet connection.
    case offline
    /// The server didn't answer in time.
    case timedOut
    /// The requested item doesn't exist.
    case notFound
    /// Too many requests in a short time.
    case rateLimited
    /// The server failed or sent something unexpected.
    case serverUnavailable
    /// The data arrived but couldn't be read.
    case unreadableData
    /// Any other failure.
    case failed
}
