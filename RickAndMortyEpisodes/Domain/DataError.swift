import Foundation

/// What can go wrong when loading episodes or characters, in terms the app cares about.
/// The Data layer translates network and storage errors into these cases, and the
/// presentation layer decides how to word them for the user.
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
