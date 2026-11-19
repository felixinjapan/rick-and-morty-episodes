import Foundation

/// Writes the character to a file other apps can open and returns the file's URL.
typealias ExportCharacter = (CharacterDetails) throws -> URL
