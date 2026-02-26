import Foundation

/// Represents the status marker of a LogSeq task
public enum TaskMarker: String, CaseIterable, Codable, Identifiable {
    case todo = "TODO"
    case doing = "DOING"
    case done = "DONE"
    case now = "NOW"
    case later = "LATER"
    case waiting = "WAITING"
    case cancelled = "CANCELLED"

    public var id: String { rawValue }

    public var isActive: Bool {
        switch self {
        case .todo, .doing, .now, .later, .waiting:
            return true
        case .done, .cancelled:
            return false
        }
    }

    public var isCompleted: Bool {
        self == .done || self == .cancelled
    }

    public var displayName: String { rawValue }

    /// The next logical status when toggling a task
    public var nextStatus: TaskMarker {
        switch self {
        case .todo: return .done
        case .doing: return .done
        case .done: return .todo
        case .now: return .done
        case .later: return .now
        case .waiting: return .todo
        case .cancelled: return .todo
        }
    }

    /// All active markers (used for filtering)
    public static var activeMarkers: [TaskMarker] {
        allCases.filter { $0.isActive }
    }

    /// Display order for grouping by status
    public static let displayOrder: [TaskMarker] = [
        .doing, .now, .todo, .later, .waiting, .done, .cancelled
    ]

    /// Sort rank for display ordering
    public var displayRank: Int {
        Self.displayOrder.firstIndex(of: self) ?? Self.displayOrder.count
    }
}
