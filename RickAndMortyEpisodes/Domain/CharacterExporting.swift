import Foundation

protocol CharacterExporting: Sendable {
    func export(_ character: CharacterDetails) throws -> URL
}
