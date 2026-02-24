import SwiftUI
import Models

extension TaskMarker {
    var iconName: String {
        switch self {
        case .todo: return "circle"
        case .doing: return "arrow.triangle.2.circlepath.circle"
        case .done: return "checkmark.circle.fill"
        case .now: return "bolt.circle.fill"
        case .later: return "clock"
        case .waiting: return "pause.circle"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .todo: return .secondary
        case .doing: return .blue
        case .done: return .green
        case .now: return .orange
        case .later: return .purple
        case .waiting: return .yellow
        case .cancelled: return .red
        }
    }
}
