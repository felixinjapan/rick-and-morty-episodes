import SwiftUI

extension CharacterStatus {
    var title: LocalizedStringResource {
        switch self {
        case .alive: .characterStatusAlive
        case .dead: .characterStatusDead
        case .unknown: .characterStatusUnknown
        }
    }

    var color: Color {
        switch self {
        case .alive: .green
        case .dead: .red
        case .unknown: .gray
        }
    }
}
