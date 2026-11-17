import CoreData
import Foundation
import SQLite3

/// SwiftData's SQLite cache is disposable. Check data pages as well as metadata before opening
/// a context, then use coordinated store destruction to rebuild confirmed corruption.
enum CacheRecovery {
    static func rebuildIfCorrupt(at url: URL) throws -> Bool {
        guard hasCorruptPages(at: url) else { return false }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        try coordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType)
        return true
    }

    private static func hasCorruptPages(at url: URL) -> Bool {
        var database: OpaquePointer?
        let opened = sqlite3_open_v2(url.path(percentEncoded: false), &database, SQLITE_OPEN_READONLY, nil)
        defer { sqlite3_close(database) }
        guard opened == SQLITE_OK else { return isSQLiteCorruption(opened) }

        // Check an in-memory copy: quick_check can report page-read I/O failures as diagnostic
        // rows too. A failed copy reports an explicit error code and leaves the source intact.
        var snapshot: OpaquePointer?
        let memoryOpened = sqlite3_open(":memory:", &snapshot)
        defer { sqlite3_close(snapshot) }
        guard memoryOpened == SQLITE_OK else { return false }
        guard let backup = sqlite3_backup_init(snapshot, "main", database, "main") else {
            return isSQLiteCorruption(sqlite3_errcode(snapshot))
        }
        let copied = sqlite3_backup_step(backup, -1)
        let finished = sqlite3_backup_finish(backup)
        guard copied == SQLITE_DONE, finished == SQLITE_OK else {
            return isSQLiteCorruption(copied) || isSQLiteCorruption(finished)
        }

        var statement: OpaquePointer?
        let prepared = sqlite3_prepare_v2(snapshot, "PRAGMA quick_check(1)", -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        guard prepared == SQLITE_OK else { return isSQLiteCorruption(prepared) }
        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else { return isSQLiteCorruption(result) }
        guard let message = sqlite3_column_text(statement, 0) else { return false }
        // quick_check returns 'ok' for a consistent database, or a diagnostic for damaged pages.
        return String(cString: message) != "ok"
    }

    private static func isSQLiteCorruption(_ code: Int32) -> Bool {
        let primaryCode = code & 0xff
        return primaryCode == SQLITE_CORRUPT || primaryCode == SQLITE_NOTADB
    }
}
