import Foundation

/// Represents LogSeq task priority [#A], [#B], [#C]
public enum TaskPriority: String, CaseIterable, Codable, Comparable, Identifiable {
    case high = "A"
    case medium = "B"
    case low = "C"
    case none = ""

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .none: return "None"
        }
    }

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        let order: [TaskPriority] = [.high, .medium, .low, .none]
        guard let l = order.firstIndex(of: lhs), let r = order.firstIndex(of: rhs) else {
            return false
        }
        return l < r
    }
}
