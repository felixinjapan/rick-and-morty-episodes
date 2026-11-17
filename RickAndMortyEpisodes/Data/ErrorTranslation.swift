import os

/// Runs a call to a data source and rethrows its failure as a `RepositoryError`, so nothing above the
/// Data layer sees HTTP or URL-loading errors. Cancellation passes through. Runs on the caller's actor.
func translatingErrors<T>(
    isolation: isolated (any Actor)? = #isolation,
    logger: Logger,
    _ operation: () async throws -> T
) async throws -> T {
    do {
        return try await operation()
    } catch let cancellation as CancellationError {
        throw cancellation
    } catch {
        logger.error("Request failed: \(String(describing: error), privacy: .public)")
        throw (error as? APIError)?.toDomain() ?? RepositoryError.failed
    }
}
