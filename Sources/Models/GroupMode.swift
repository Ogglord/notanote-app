import Foundation

/// How to group todos in the list
public enum GroupMode: String, CaseIterable, Identifiable {
    case byStatus = "Status"
    case byPage = "Page"
    case byPriority = "Priority"
    case byDate = "Date"
    case bySource = "Source"
    case flat = "None"

    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

/// How to filter the displayed tasks
public enum FilterMode: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case today = "Today"
    case overdue = "Overdue"
    case done = "Done"

    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

/// Secondary sort order within each source group
public enum SortOrder: String, CaseIterable, Identifiable {
    case priority = "Priority"
    case dueDate = "Due Date"
    case dateCreated = "Date Created"

    public var id: String { rawValue }
    public var displayName: String { rawValue }

    private static let key = "secondarySortOrder"

    public static var saved: SortOrder {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let order = SortOrder(rawValue: raw) else {
            return .priority
        }
        return order
    }

    public static func save(_ order: SortOrder) {
        UserDefaults.standard.set(order.rawValue, forKey: key)
    }
}

/// A group of todos for display
public struct TodoGroup: Identifiable {
    public let id: String
    public let title: String
    public let icon: String?
    public var items: [TodoItem]

    public init(id: String, title: String, icon: String?, items: [TodoItem]) {
        self.id = id
        self.title = title
        self.icon = icon
        self.items = items
    }
}
