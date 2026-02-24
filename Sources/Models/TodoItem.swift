import Foundation

/// Represents a single task parsed from a LogSeq markdown file
public struct TodoItem: Identifiable, Hashable {
    /// Unique identifier based on file path and line number
    public let id: String
    /// The task status marker (TODO, DONE, NOW, LATER, etc.)
    public var marker: TaskMarker
    /// The text content of the task (without the marker, priority, dates)
    public var content: String
    /// The raw full line content from the file
    public var rawLine: String
    /// Task priority [#A], [#B], [#C]
    public var priority: TaskPriority
    /// Scheduled date (SCHEDULED: <2024-01-15>)
    public var scheduledDate: Date?
    /// Deadline date (DEADLINE: <2024-01-15>)
    public var deadline: Date?
    /// Tags extracted from the line (#tag1 #tag2)
    public var tags: [String]
    /// Page references extracted ([[page]])
    public var pageRefs: [String]
    /// Source file path
    public let filePath: String
    /// Line number in the source file (0-based)
    public let lineNumber: Int
    /// Journal date extracted from the journal filename
    public var journalDate: Date?
    /// Indentation level (number of tabs)
    public var indentLevel: Int
    /// The source of this todo (manual, linear, pylon)
    public var source: TodoSource
    /// URL to open the item in its source app (Linear or Pylon)
    public var sourceURL: URL?

    public init(
        id: String,
        marker: TaskMarker,
        content: String,
        rawLine: String,
        priority: TaskPriority,
        scheduledDate: Date?,
        deadline: Date?,
        tags: [String],
        pageRefs: [String],
        filePath: String,
        lineNumber: Int,
        journalDate: Date?,
        indentLevel: Int,
        source: TodoSource,
        sourceURL: URL?
    ) {
        self.id = id
        self.marker = marker
        self.content = content
        self.rawLine = rawLine
        self.priority = priority
        self.scheduledDate = scheduledDate
        self.deadline = deadline
        self.tags = tags
        self.pageRefs = pageRefs
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.journalDate = journalDate
        self.indentLevel = indentLevel
        self.source = source
        self.sourceURL = sourceURL
    }

    /// Display-friendly date string for the journal date
    public var journalDateString: String? {
        guard let date = journalDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Whether this task is overdue
    public var isOverdue: Bool {
        guard let deadline = deadline else { return false }
        return deadline < Date() && marker.isActive
    }

    /// Whether this task is scheduled for today
    public var isScheduledToday: Bool {
        guard let scheduled = scheduledDate else { return false }
        return Calendar.current.isDateInToday(scheduled)
    }

    /// The source page name (derived from file path)
    public var pageName: String {
        let filename = (filePath as NSString).lastPathComponent
        let name = (filename as NSString).deletingPathExtension
        // Convert journal filenames like 2024_01_15 to readable dates
        if let date = journalDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return name.replacingOccurrences(of: "_", with: " ")
    }
}
