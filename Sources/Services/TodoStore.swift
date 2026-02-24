import Foundation
import Observation
import Models

/// Main data store that loads, watches, and manages todo items from a LogSeq graph
@Observable
public final class TodoStore {

    // MARK: - Published state

    public private(set) var items: [TodoItem] = []
    public private(set) var isLoading = false
    public private(set) var lastUpdated: Date?

    // MARK: - Configuration

    public var graphPath: String {
        didSet {
            UserDefaults.standard.set(graphPath, forKey: Self.graphPathKey)
            restartWatcher()
            reload()
        }
    }

    // MARK: - Private

    private static let graphPathKey = "logseq.graphPath"
    private static let refreshIntervalKey = "autoRefreshInterval"
    private var fileWatcher: FileWatcher?
    private var refreshObserver: NSObjectProtocol?

    /// Refresh interval in minutes (read from UserDefaults, default 2 min)
    private var refreshIntervalMinutes: Double {
        let val = UserDefaults.standard.double(forKey: Self.refreshIntervalKey)
        return val > 0 ? val : 2.0
    }

    // MARK: - Init

    public init(graphPath: String) {
        // Prefer persisted path, fall back to provided default
        let stored = UserDefaults.standard.string(forKey: Self.graphPathKey)
        self.graphPath = stored ?? graphPath

        // Persist if not already stored
        if stored == nil {
            UserDefaults.standard.set(graphPath, forKey: Self.graphPathKey)
        }

        reload()
        startWatcher()
        observeRefreshIntervalChanges()
    }

    // MARK: - Public API

    /// Scan all markdown files in journals/ and pages/, parse them, and update items
    public func reload() {
        isLoading = true
        let path = graphPath

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let parsed = Self.loadItems(from: path)

            DispatchQueue.main.async {
                guard let self else { return }
                self.items = parsed
                self.isLoading = false
                self.lastUpdated = Date()
            }
        }
    }

    /// Toggle a task to its next logical status
    public func toggleTask(_ item: TodoItem) {
        setMarker(item, to: item.marker.nextStatus)
    }

    /// Set a specific marker on a task, write it to disk, and reload
    public func setMarker(_ item: TodoItem, to marker: TaskMarker) {
        do {
            try LogSeqParser.updateTaskMarker(in: item.filePath, at: item.lineNumber, to: marker)
            reload()
        } catch {
            print("[TodoStore] Failed to update marker: \(error.localizedDescription)")
        }
    }

    /// Add a new TODO item to today's journal file
    public func addTodoToJournal(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayFilename = formatter.string(from: Date()) + ".md"

        let journalsDir = (graphPath as NSString).appendingPathComponent("journals")
        let filePath = (journalsDir as NSString).appendingPathComponent(todayFilename)

        let newLine = "- TODO \(text)"

        let fm = FileManager.default

        // Ensure journals directory exists
        if !fm.fileExists(atPath: journalsDir) {
            try? fm.createDirectory(atPath: journalsDir, withIntermediateDirectories: true)
        }

        if fm.fileExists(atPath: filePath),
           let data = fm.contents(atPath: filePath),
           var content = String(data: data, encoding: .utf8) {
            // Append to existing file: add at the top (after any leading empty lines)
            // Find the first non-empty line position to insert before it,
            // or just prepend if the file starts with content
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = newLine + "\n"
            } else {
                content = newLine + "\n" + content
            }
            try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } else {
            // Create new journal file
            let content = newLine + "\n"
            try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
        }

        reload()
    }

    // MARK: - File watching

    private func startWatcher() {
        let journalsDir = (graphPath as NSString).appendingPathComponent("journals")
        let pagesDir = (graphPath as NSString).appendingPathComponent("pages")
        let intervalSeconds = refreshIntervalMinutes * 60.0

        fileWatcher = FileWatcher(
            paths: [journalsDir, pagesDir],
            pollInterval: intervalSeconds
        ) { [weak self] in
            self?.reload()
        }
        fileWatcher?.start()
    }

    private func restartWatcher() {
        fileWatcher?.stop()
        fileWatcher = nil
        startWatcher()
    }

    private func observeRefreshIntervalChanges() {
        refreshObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let newSeconds = self.refreshIntervalMinutes * 60.0
            self.fileWatcher?.updatePollInterval(newSeconds)
            // Re-sort in-memory items (picks up source order changes from Settings)
            self.items = Self.sortItems(self.items)
        }
    }

    // MARK: - Loading

    /// Collect and sort all todo items from the graph
    private static func loadItems(from graphPath: String) -> [TodoItem] {
        let fm = FileManager.default
        var allItems: [TodoItem] = []

        let directories = ["journals", "pages"]
        for dir in directories {
            let dirPath = (graphPath as NSString).appendingPathComponent(dir)
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".md") {
                let fullPath = (dirPath as NSString).appendingPathComponent(file)
                let items = LogSeqParser.parseFile(at: fullPath)
                allItems.append(contentsOf: items)
            }
        }

        return sortItems(allItems)
    }

    /// Sort: active first, then by source order, then by priority (high->low), then by journal date (newest first)
    private static func sortItems(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { a, b in
            // Active items before completed
            if a.marker.isActive != b.marker.isActive {
                return a.marker.isActive
            }
            // Source order (user-configurable via Settings)
            if a.source != b.source {
                return a.source.sortRank < b.source.sortRank
            }
            // Higher priority first (high < medium < low < none in Comparable)
            if a.priority != b.priority {
                return a.priority < b.priority
            }
            // Newer journal dates first
            let dateA = a.journalDate ?? .distantPast
            let dateB = b.journalDate ?? .distantPast
            return dateA > dateB
        }
    }
}
