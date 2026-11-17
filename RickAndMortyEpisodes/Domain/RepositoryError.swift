import Foundation

/// Failures exposed by repositories when loading resources.
enum RepositoryError: Error, Equatable {
    case offline
    case timedOut
    case notFound
    case rateLimited
    case serverUnavailable
    case unreadableData
    case failed
}
