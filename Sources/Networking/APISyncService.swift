import Foundation
import Observation

/// Orchestrator that manages periodic syncing from Linear and Pylon APIs
/// into the local LogSeq digest files.
@Observable
public final class APISyncService {
    // MARK: - Observable State

    public private(set) var isSyncing = false
    public private(set) var lastLinearSync: Date?
    public private(set) var lastPylonSync: Date?
    public private(set) var lastError: String?

    // MARK: - Settings (persisted to UserDefaults)

    public var linearEnabled: Bool {
        didSet { UserDefaults.standard.set(linearEnabled, forKey: "api.linearEnabled") }
    }
    public var pylonEnabled: Bool {
        didSet { UserDefaults.standard.set(pylonEnabled, forKey: "api.pylonEnabled") }
    }
    public var syncIntervalMinutes: Double {
        didSet { UserDefaults.standard.set(syncIntervalMinutes, forKey: "api.syncInterval") }
    }

    // MARK: - Private

    private var digestWriter: DigestWriter?
    private var syncTask: Task<Void, Never>?

    // MARK: - Init

    public init() {
        self.linearEnabled = UserDefaults.standard.object(forKey: "api.linearEnabled") as? Bool ?? false
        self.pylonEnabled = UserDefaults.standard.object(forKey: "api.pylonEnabled") as? Bool ?? false
        self.syncIntervalMinutes = UserDefaults.standard.object(forKey: "api.syncInterval") as? Double ?? 15.0
    }

    /// Provide the digest writer implementation (call this from the App layer).
    public func configure(digestWriter: DigestWriter) {
        self.digestWriter = digestWriter
    }

    // MARK: - Sync All

    /// Run a full sync of all enabled sources.
    public func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil

        do {
            if linearEnabled {
                try await syncLinear()
            }
        } catch {
            lastError = error.localizedDescription
        }

        do {
            if pylonEnabled {
                try await syncPylon()
            }
        } catch {
            // Append to existing error if Linear also failed
            if let existing = lastError {
                lastError = existing + " | " + error.localizedDescription
            } else {
                lastError = error.localizedDescription
            }
        }

        isSyncing = false
    }

    // MARK: - Individual Sync

    public func syncLinear() async throws {
        guard let apiKey = KeychainHelper.loadToken(for: "linear") else {
            throw APIError.noToken(service: "Linear")
        }
        guard let writer = digestWriter else { return }

        let client = LinearAPIClient(apiKey: apiKey)
        let issues = try await client.fetchMyIssues()

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

        try writer.writeDigest(source: "linear", items: items)
        lastLinearSync = Date()
    }

    public func syncPylon() async throws {
        guard let apiKey = KeychainHelper.loadToken(for: "pylon") else {
            throw APIError.noToken(service: "Pylon")
        }
        guard let writer = digestWriter else { return }

        let client = PylonAPIClient(apiKey: apiKey)
        let issues = try await client.fetchMyIssues()

        let items = issues.map { issue in
            DigestItem(
                text: issue.title,
                sourceId: issue.id,
                url: "https://app.usepylon.com/issues/\(issue.issue_number)",
                identifier: "#\(issue.issue_number)",
                priority: mapPylonPriority(issue.priority),
                status: "TODO"
            )
        }

        try writer.writeDigest(source: "pylon", items: items)
        lastPylonSync = Date()
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
