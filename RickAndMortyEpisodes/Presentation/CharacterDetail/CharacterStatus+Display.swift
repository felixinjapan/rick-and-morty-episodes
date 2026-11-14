import SwiftUI

extension CharacterStatus {
    /// The status as shown to the user, from the string catalog.
    var title: LocalizedStringResource {
        switch self {
        case .alive: .characterStatusAlive
        case .dead: .characterStatusDead
        case .unknown: .characterStatusUnknown
        }
    }

    /// The colour of the dot next to the status.
    var color: Color {
        switch self {
        case .alive: .green
        case .dead: .red
        case .unknown: .gray
        }
    }
}
