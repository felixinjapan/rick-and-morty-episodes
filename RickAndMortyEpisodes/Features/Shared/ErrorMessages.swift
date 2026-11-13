import Foundation

extension EpisodeError {
    /// The sentence shown to the user.
    var message: String {
        switch self {
        case .offline: "You appear to be offline. Check your connection, then try again."
        case .timedOut: "The server took too long to respond. Try again in a moment."
        case .notFound: "This item could not be found."
        case .rateLimited: "Too many requests. Please try again in a moment."
        case .serverUnavailable: "The server is having problems. Please try again later."
        case .unreadableData: "The server's data could not be read. Try again later."
        case .failed: "Something went wrong. Try again in a moment."
        }
    }
}

extension Error {
    /// Message for the UI. The repository only throws `EpisodeError` (or cancellation),
    /// so anything else falls back to the generic text.
    var userMessage: String {
        ((self as? EpisodeError) ?? .failed).message
    }
}
