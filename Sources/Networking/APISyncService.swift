import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.logseqtodos", category: "APISyncService")

/// Orchestrator that manages periodic syncing from Linear and Pylon APIs
/// into the local LogSeq digest files.
@Observable
public final class APISyncService {
    // MARK: - Observable State

    public private(set) var isSyncing = false
    public private(set) var lastLinearSync: Date?
    public private(set) var lastPylonSync: Date?
    public private(set) var lastError: String?
    public private(set) var syncLog: [String] = []

    private func log(_ message: String) {
        let entry = "[\(Self.timestampFormatter.string(from: Date()))] \(message)"
        logger.info("\(entry)")
        syncLog.append(entry)
        // Keep last 50 entries
        if syncLog.count > 50 { syncLog.removeFirst(syncLog.count - 50) }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    // MARK: - Settings (persisted to UserDefaults)

    public var linearEnabled: Bool {
        didSet { UserDefaults.standard.set(linearEnabled, forKey: "linear.enabled") }
    }
    public var pylonEnabled: Bool {
        didSet { UserDefaults.standard.set(pylonEnabled, forKey: "pylon.enabled") }
    }
    public var syncIntervalMinutes: Double {
        didSet { UserDefaults.standard.set(syncIntervalMinutes, forKey: "api.syncInterval") }
    }

    // MARK: - Private

    private var digestWriter: DigestWriter?
    private var syncTask: Task<Void, Never>?

    // MARK: - Init

    public init() {
        self.linearEnabled = UserDefaults.standard.bool(forKey: "linear.enabled")
        self.pylonEnabled = UserDefaults.standard.bool(forKey: "pylon.enabled")
        self.syncIntervalMinutes = UserDefaults.standard.object(forKey: "api.syncInterval") as? Double ?? 15.0
    }

    /// Provide the digest writer implementation (call this from the App layer).
    public func configure(digestWriter: DigestWriter) {
        self.digestWriter = digestWriter
    }

    // MARK: - Sync All

    /// Run a full sync of all enabled sources.
    public func syncAll() async {
        guard !isSyncing else {
            log("Sync already in progress, skipping")
            return
        }
        isSyncing = true
        lastError = nil

        // Read live from UserDefaults in case the user toggled settings
        let isLinearOn = UserDefaults.standard.bool(forKey: "linear.enabled")
        let isPylonOn = UserDefaults.standard.bool(forKey: "pylon.enabled")
        log("Starting sync (linear=\(isLinearOn), pylon=\(isPylonOn))")

        if digestWriter == nil {
            log("ERROR: No digest writer configured")
        }

        do {
            if isLinearOn {
                try await syncLinear()
            }
        } catch {
            log("Linear sync failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }

        do {
            if isPylonOn {
                try await syncPylon()
            }
        } catch {
            log("Pylon sync failed: \(error.localizedDescription)")
            if let existing = lastError {
                lastError = existing + " | " + error.localizedDescription
            } else {
                lastError = error.localizedDescription
            }
        }

        isSyncing = false
        log("Sync finished")

        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name("apiSyncCompleted"), object: nil)
        }
    }

    // MARK: - Individual Sync

    public func syncLinear() async throws {
        log("Linear: loading token from keychain...")
        guard let apiKey = KeychainHelper.loadToken(for: "linear-api-token") else {
            throw APIError.noToken(service: "Linear")
        }
        log("Linear: token loaded (\(apiKey.prefix(8))...)")
        guard let writer = digestWriter else {
            log("Linear: ERROR no digest writer")
            return
        }

        log("Linear: fetching issues...")
        let client = LinearAPIClient(apiKey: apiKey)
        let issues = try await client.fetchMyIssues()
        log("Linear: fetched \(issues.count) issues")

        let items = issues.map { issue in
            DigestItem(
                text: issue.title,
                sourceId: issue.id,
                url: issue.url,
                identifier: issue.identifier,
                priority: mapLinearPriority(issue.priority),
                status: "TODO"
            )
        }

        let path = writer.digestFilePath(for: "linear")
        log("Linear: writing \(items.count) items to \(path)")
        try writer.writeDigest(source: "linear", items: items)
        lastLinearSync = Date()
        log("Linear: sync complete")
    }

    public func syncPylon() async throws {
        log("Pylon: loading token from keychain...")
        guard let apiKey = KeychainHelper.loadToken(for: "pylon-api-token") else {
            throw APIError.noToken(service: "Pylon")
        }
        log("Pylon: token loaded")
        guard let writer = digestWriter else {
            log("Pylon: ERROR no digest writer")
            return
        }

        log("Pylon: fetching issues...")
        let client = PylonAPIClient(apiKey: apiKey)
        let issues = try await client.fetchMyIssues()
        log("Pylon: fetched \(issues.count) issues")

        let items = issues.map { issue in
            DigestItem(
                text: issue.title,
                sourceId: issue.id,
                url: "https://app.usepylon.com/issues?issueNumber=\(issue.number)",
                identifier: "#\(issue.number)",
                status: "TODO"
            )
        }

        let path = writer.digestFilePath(for: "pylon")
        log("Pylon: writing \(items.count) items to \(path)")
        try writer.writeDigest(source: "pylon", items: items)
        lastPylonSync = Date()
        log("Pylon: sync complete")
    }

    // MARK: - Periodic Sync

    public func startPeriodicSync() {
        stopPeriodicSync()
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.syncAll()
                let interval = self.syncIntervalMinutes * 60
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stopPeriodicSync() {
        syncTask?.cancel()
        syncTask = nil
    }

    // MARK: - Priority Mapping

    private func mapLinearPriority(_ priority: Int) -> String? {
        switch priority {
        case 1, 2: return "A"
        case 3:    return "B"
        case 4:    return "C"
        default:   return nil
        }
    }

    private func mapPylonPriority(_ priority: String?) -> String? {
        switch priority?.lowercased() {
        case "urgent", "high": return "A"
        case "medium":         return "B"
        case "low":            return "C"
        default:               return nil
        }
    }
}
