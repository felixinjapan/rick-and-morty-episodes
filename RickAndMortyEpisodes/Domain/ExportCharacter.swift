import Foundation

/// `@Sendable` because the share sheet calls it when the user picks a destination.
typealias ExportCharacter = @Sendable (CharacterDetails) throws -> URL
