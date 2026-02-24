import Foundation

/// Watches directories for file changes using periodic polling of directory modification dates.
public final class FileWatcher {

    private let paths: [String]
    private let onChange: () -> Void
    private let debounceInterval: TimeInterval

    private var timer: DispatchSourceTimer?
    private var lastModDates: [String: Date] = [:]
    private var pendingNotify: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.notanote.filewatcher", qos: .utility)
    private var currentPollInterval: TimeInterval

    /// Create a new file watcher.
    /// - Parameters:
    ///   - paths: Directory paths to monitor
    ///   - pollInterval: How often to check for changes (in seconds)
    ///   - debounceInterval: Time to coalesce rapid changes (default 0.5s)
    ///   - onChange: Callback invoked on the main queue when changes are detected
    public init(
        paths: [String],
        pollInterval: TimeInterval = 120,
        debounceInterval: TimeInterval = 0.5,
        onChange: @escaping () -> Void
    ) {
        self.paths = paths
        self.currentPollInterval = pollInterval
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    /// Start watching for changes
    public func start() {
        guard timer == nil else { return }

        // Snapshot current state so we don't fire immediately
        lastModDates = currentModDates()

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(
            deadline: .now() + currentPollInterval,
            repeating: currentPollInterval,
            leeway: .seconds(1)
        )
        source.setEventHandler { [weak self] in
            self?.poll()
        }
        timer = source
        source.resume()
    }

    /// Stop watching
    public func stop() {
        timer?.cancel()
        timer = nil
        pendingNotify?.cancel()
        pendingNotify = nil
    }

    /// Update the poll interval. Restarts the timer with the new interval.
    public func updatePollInterval(_ newInterval: TimeInterval) {
        guard newInterval != currentPollInterval else { return }
        currentPollInterval = newInterval
        if timer != nil {
            stop()
            start()
        }
    }

    // MARK: - Private

    private func poll() {
        let current = currentModDates()
        guard current != lastModDates else { return }
        lastModDates = current
        scheduleNotify()
    }

    /// Debounce: only fire the callback after no new changes for `debounceInterval`
    private func scheduleNotify() {
        pendingNotify?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.onChange()
            }
        }
        pendingNotify = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Collect modification dates for all .md files in the watched directories
    private func currentModDates() -> [String: Date] {
        let fm = FileManager.default
        var result: [String: Date] = [:]

        for dir in paths {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".md") {
                let fullPath = (dir as NSString).appendingPathComponent(entry)
                if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                   let mod = attrs[.modificationDate] as? Date {
                    result[fullPath] = mod
                }
            }
        }
        return result
    }
}
