import SwiftUI
import Models

extension TodoSource {
    var iconName: String {
        switch self {
        case .manual: return "person.fill"
        case .linear: return "line.3.horizontal.decrease.circle"
        case .pylon: return "headset.circle"
        }
    }

    var color: Color {
        switch self {
        case .manual: return .secondary
        case .linear: return .indigo
        case .pylon: return .teal
        }
    }

    var badgeColor: Color {
        switch self {
        case .manual: return .clear
        case .linear: return .indigo
        case .pylon: return .teal
        }
    }
}
