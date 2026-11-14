import Foundation

extension EpisodeError {
    /// The sentence shown to the user, from the string catalog.
    var message: String {
        switch self {
        case .offline:
            String(localized: "You appear to be offline. Check your connection, then try again.", comment: "Error message: No internet connection")
        case .timedOut:
            String(localized: "The server took too long to respond. Try again in a moment.", comment: "Error message: Request timed out")
        case .notFound:
            String(localized: "This item could not be found.", comment: "Error message: The requested episode or character doesn't exist")
        case .rateLimited:
            String(localized: "Too many requests. Please try again in a moment.", comment: "Error message: The server is rate limiting the app")
        case .serverUnavailable:
            String(localized: "The server is having problems. Please try again later.", comment: "Error message: Server error or unexpected response")
        case .unreadableData:
            String(localized: "The server's data could not be read. Try again later.", comment: "Error message: The response couldn't be decoded")
        case .failed:
            String(localized: "Something went wrong. Try again in a moment.", comment: "Error message: Any other failure")
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
