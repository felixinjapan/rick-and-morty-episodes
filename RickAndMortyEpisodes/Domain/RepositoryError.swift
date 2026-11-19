import Foundation

enum RepositoryError: Error, Equatable {
    case offline
    case timedOut
    case notFound
    case rateLimited
    case serverUnavailable
    case unreadableData
    case failed
}
