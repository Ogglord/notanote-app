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
