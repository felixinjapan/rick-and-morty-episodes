import Foundation

/// Writes the character to a file other apps can open and returns the file's URL.
/// `@Sendable` because the share sheet calls it when the user picks a destination.
typealias ExportCharacter = @Sendable (CharacterDetails) throws -> URL
