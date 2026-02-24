import SwiftUI
import Models

extension GroupMode {
    var iconName: String {
        switch self {
        case .byStatus: return "checklist"
        case .byPage: return "doc.text"
        case .byPriority: return "exclamationmark.triangle"
        case .byDate: return "calendar"
        case .bySource: return "tray.2"
        case .flat: return "list.bullet"
        }
    }
}

extension FilterMode {
    var iconName: String {
        switch self {
        case .all: return "tray.full"
        case .active: return "circle"
        case .today: return "sun.max"
        case .overdue: return "exclamationmark.triangle"
        case .done: return "checkmark.circle"
        }
    }
}
