import os

/// Runs a call to a data source and rethrows its failure as a `DataError`, so nothing
/// above the Data layer depends on HTTP or URL-loading errors. Cancellation passes through
/// unchanged. Used by every repository; runs on the calling repository's actor.
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
        throw (error as? APIError)?.toDomain() ?? DataError.failed
    }
}
