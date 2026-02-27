import SwiftUI
import Models
import Services

@Observable
class TodoListViewModel {
    var store: TodoStore

    var filterMode: FilterMode {
        didSet { UserDefaults.standard.set(filterMode.rawValue, forKey: "filterMode") }
    }

    var groupMode: GroupMode {
        didSet { UserDefaults.standard.set(groupMode.rawValue, forKey: "groupMode") }
    }

    var searchText: String = ""

    var selectedMarkers: Set<TaskMarker> = Set(TaskMarker.activeMarkers)

    var showSettings: Bool = false

    var showCompleted: Bool {
        didSet { UserDefaults.standard.set(showCompleted, forKey: "showCompleted") }
    }

    var sourceFilter: TodoSource? {
        didSet { UserDefaults.standard.set(sourceFilter?.rawValue ?? "", forKey: "sourceFilter") }
    }

    init(store: TodoStore) {
        self.store = store
        self.filterMode = FilterMode(rawValue: UserDefaults.standard.string(forKey: "filterMode") ?? "") ?? .active
        self.groupMode = GroupMode(rawValue: UserDefaults.standard.string(forKey: "groupMode") ?? "") ?? .byPage
        self.showCompleted = UserDefaults.standard.bool(forKey: "showCompleted")
        let savedSource = UserDefaults.standard.string(forKey: "sourceFilter") ?? ""
        self.sourceFilter = savedSource.isEmpty ? nil : TodoSource(rawValue: savedSource)
    }

    // MARK: - Computed Properties

    var filteredItems: [TodoItem] {
        var items = store.items

        switch filterMode {
        case .all:
            break
        case .active:
            items = items.filter { $0.marker.isActive }
        case .today:
            items = items.filter { item in
                let cal = Calendar.current
                if let journal = item.journalDate, cal.isDateInToday(journal) { return true }
                if let scheduled = item.scheduledDate, cal.isDateInToday(scheduled) { return true }
                if let deadline = item.deadline, cal.isDateInToday(deadline) { return true }
                return false
            }
        case .overdue:
            items = items.filter { $0.isOverdue }
        case .done:
            items = items.filter { $0.marker.isCompleted }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter { item in
                item.content.lowercased().contains(query)
                    || item.tags.contains(where: { $0.lowercased().contains(query) })
                    || item.pageRefs.contains(where: { $0.lowercased().contains(query) })
            }
        }

        // Only apply marker/completed filters when not already filtering by done or all
        if filterMode != .done && filterMode != .all {
            items = items.filter { selectedMarkers.contains($0.marker) }

            if !showCompleted {
                items = items.filter { !$0.marker.isCompleted }
            }
        }

        if let sourceFilter {
            items = items.filter { $0.source == sourceFilter }
        }

        return items
    }

    var groupedItems: [TodoGroup] {
        let items = filteredItems

        var groups: [TodoGroup]

        switch groupMode {
        case .byStatus:
            groups = groupByStatus(items)
        case .byPage:
            groups = groupByPage(items)
        case .byPriority:
            groups = groupByPriority(items)
        case .byDate:
            groups = groupByDate(items)
        case .bySource:
            groups = groupBySource(items)
        case .flat:
            groups = [TodoGroup(id: "all", title: "All Tasks", icon: nil, items: items)]
        }

        // Re-sort groups so groups containing higher-priority sources appear first.
        // Preserves original order as tiebreaker for groups with the same source rank.
        // Skip for byStatus (status display order matters) and bySource/flat.
        if groupMode != .bySource && groupMode != .flat && groupMode != .byStatus {
            let indexed = groups.enumerated().map { ($0.offset, $0.element) }
            groups = indexed.sorted { a, b in
                let aRank = a.1.items.map(\.source.sortRank).min() ?? Int.max
                let bRank = b.1.items.map(\.source.sortRank).min() ?? Int.max
                if aRank != bRank { return aRank < bRank }
                return a.0 < b.0
            }.map(\.1)
        }

        return groups
    }

    var activeTodoCount: Int {
        store.items.filter { $0.marker.isActive }.count
    }

    // MARK: - Actions

    func toggleTask(_ item: TodoItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.toggleTask(item)
        }
    }

    func setMarker(_ item: TodoItem, to marker: TaskMarker) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.setMarker(item, to: marker)
        }
    }

    func addTodo(_ text: String) {
        store.addTodoToJournal(text)
    }

    func updateContent(_ item: TodoItem, newContent: String) {
        store.updateContent(item, newContent: newContent)
    }

    func updatePriority(_ item: TodoItem, to priority: TaskPriority) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.updatePriority(item, to: priority)
        }
    }

    func updateDeadline(_ item: TodoItem, to deadline: Date?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            store.updateDeadline(item, to: deadline)
        }
    }

    // MARK: - Grouping Helpers

    private func groupByStatus(_ items: [TodoItem]) -> [TodoGroup] {
        let grouped = Dictionary(grouping: items) { $0.marker }
        return TaskMarker.displayOrder.compactMap { marker in
            guard let group = grouped[marker], !group.isEmpty else { return nil }
            return TodoGroup(
                id: "status-\(marker.rawValue)",
                title: marker.displayName,
                icon: marker.iconName,
                items: group
            )
        }
    }

    private func groupByPage(_ items: [TodoItem]) -> [TodoGroup] {
        let grouped = Dictionary(grouping: items) { $0.pageName }
        return grouped.keys.sorted().map { name in
            TodoGroup(
                id: "page-\(name)",
                title: name,
                icon: "doc.text",
                items: grouped[name]!
            )
        }
    }

    private func groupByPriority(_ items: [TodoItem]) -> [TodoGroup] {
        let grouped = Dictionary(grouping: items) { $0.priority }
        return TaskPriority.allCases.compactMap { priority in
            guard let group = grouped[priority], !group.isEmpty else { return nil }
            return TodoGroup(
                id: "priority-\(priority.rawValue)",
                title: priority.displayName,
                icon: priority.icon.isEmpty ? nil : priority.icon,
                items: group
            )
        }
    }

    private func groupByDate(_ items: [TodoItem]) -> [TodoGroup] {
        let cal = Calendar.current
        let now = Date()

        var today: [TodoItem] = []
        var yesterday: [TodoItem] = []
        var thisWeek: [TodoItem] = []
        var older: [TodoItem] = []

        for item in items {
            guard let date = item.journalDate else {
                older.append(item)
                continue
            }
            if cal.isDateInToday(date) {
                today.append(item)
            } else if cal.isDateInYesterday(date) {
                yesterday.append(item)
            } else if let weekAgo = cal.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
                thisWeek.append(item)
            } else {
                older.append(item)
            }
        }

        var groups: [TodoGroup] = []
        if !today.isEmpty {
            groups.append(TodoGroup(id: "date-today", title: "Today", icon: "sun.max", items: today))
        }
        if !yesterday.isEmpty {
            groups.append(TodoGroup(id: "date-yesterday", title: "Yesterday", icon: "arrow.uturn.backward", items: yesterday))
        }
        if !thisWeek.isEmpty {
            groups.append(TodoGroup(id: "date-week", title: "This Week", icon: "calendar", items: thisWeek))
        }
        if !older.isEmpty {
            groups.append(TodoGroup(id: "date-older", title: "Older", icon: "archivebox", items: older))
        }
        return groups
    }

    private func groupBySource(_ items: [TodoItem]) -> [TodoGroup] {
        let grouped = Dictionary(grouping: items) { $0.source }
        return TodoSource.savedOrder.compactMap { source in
            guard let group = grouped[source], !group.isEmpty else { return nil }
            return TodoGroup(
                id: "source-\(source.rawValue)",
                title: source.displayName,
                icon: source.iconName,
                items: group
            )
        }
    }

    // MARK: - Source Counts

    /// Counts of active items per source (for the source filter badges)
    var sourceCounts: [TodoSource: Int] {
        var counts: [TodoSource: Int] = [:]
        let active = store.items.filter { $0.marker.isActive }
        for source in TodoSource.allCases {
            counts[source] = active.filter { $0.source == source }.count
        }
        return counts
    }
}
