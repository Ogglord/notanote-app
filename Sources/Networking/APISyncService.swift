import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.notanote", category: "APISyncService")

/// Orchestrator that manages periodic syncing from Linear and Pylon APIs
/// into the local LogSeq digest files.
@Observable
public final class APISyncService {
    // MARK: - Observable State

    public private(set) var isSyncing = false
    public private(set) var lastLinearSync: Date?
    public private(set) var lastPylonSync: Date?
    public private(set) var lastLinearCount: Int = 0
    public private(set) var lastPylonCount: Int = 0
    public private(set) var lastNotificationSync: Date?
    public private(set) var lastError: String?
    public private(set) var syncLog: [String] = []

    /// Most recent sync completion time (whichever source finished last)
    public var lastSyncDate: Date? {
        [lastLinearSync, lastPylonSync].compactMap { $0 }.max()
    }

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
    private var notificationService: NotificationService?
    private var syncTask: Task<Void, Never>?

    // MARK: - Init

    public init() {
        self.linearEnabled = UserDefaults.standard.bool(forKey: "linear.enabled")
        self.pylonEnabled = UserDefaults.standard.bool(forKey: "pylon.enabled")
        self.syncIntervalMinutes = UserDefaults.standard.object(forKey: "api.syncInterval") as? Double ?? 15.0
    }

    /// Provide the digest writer and notification service (call this from the App layer).
    public func configure(digestWriter: DigestWriter, notificationService: NotificationService? = nil) {
        self.digestWriter = digestWriter
        self.notificationService = notificationService
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

        // Notification sync (Linear inbox + new Pylon issue detection)
        let isNotificationsOn = UserDefaults.standard.object(forKey: "notifications.enabled") as? Bool ?? true
        if isNotificationsOn {
            do {
                try await syncNotifications(linearEnabled: isLinearOn, pylonEnabled: isPylonOn)
            } catch {
                log("Notification sync failed: \(error.localizedDescription)")
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
        lastLinearCount = items.count
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

        let client = PylonAPIClient(apiKey: apiKey)

        let pylonEmail = UserDefaults.standard.string(forKey: "pylon.email") ?? ""
        let userId: String?
        if pylonEmail.isEmpty {
            log("Pylon: no email configured, skipping assignee filter")
            userId = nil
        } else {
            log("Pylon: looking up user by email \(pylonEmail)...")
            do {
                userId = try await client.fetchCurrentUserId(email: pylonEmail)
                log("Pylon: user ID = \(userId ?? "nil")")
            } catch {
                log("Pylon: could not fetch user ID (\(error.localizedDescription)), will skip assignee filter")
                userId = nil
            }
        }

        log("Pylon: fetching issues...")
        let allIssues = try await client.fetchAllRecentIssues()
        let validStates: Set<String> = ["new", "waiting_on_you"]
        var issues = allIssues.filter { validStates.contains($0.state) }
        log("Pylon: \(allIssues.count) total → \(issues.count) with state new/waiting_on_you")
        if let userId {
            issues = issues.filter { $0.resolvedAssigneeId == userId }
            log("Pylon: \(issues.count) assigned to me (\(userId.prefix(8))...)")
        }
        for issue in issues.prefix(5) {
            log("  - #\(issue.number) \"\(issue.title)\" state=\(issue.state)")
        }
        if issues.count > 5 { log("  ... and \(issues.count - 5) more") }

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
        lastPylonCount = items.count
        log("Pylon: sync complete")
    }

    // MARK: - Notification Sync

    public func syncNotifications(linearEnabled: Bool, pylonEnabled: Bool) async throws {
        guard let writer = digestWriter, let notifService = notificationService else { return }

        var allDigestItems: [DigestItem] = []
        var allPanelItems: [NotificationItem] = []
        var nativeItems: [(title: String, body: String, id: String)] = []

        // 1. Fetch Linear inbox notifications
        if linearEnabled {
            if let apiKey = KeychainHelper.loadToken(for: "linear-api-token") {
                log("Notifications: fetching Linear inbox...")
                let client = LinearAPIClient(apiKey: apiKey)
                let notifications = try await client.fetchNotifications(first: 10)
                log("Notifications: fetched \(notifications.count) inbox items")

                let newItems = notifService.processLinearNotifications(notifications)

                // Build digest + panel items for ALL inbox entries
                for n in notifications {
                    guard let issue = n.issue else { continue }
                    let isUnread = n.readAt == nil

                    allDigestItems.append(DigestItem(
                        text: "[\(humanReadableType(n.type))] \(issue.title)",
                        sourceId: n.id,
                        url: issue.url,
                        identifier: issue.identifier,
                        priority: nil,
                        status: isUnread ? "TODO" : "DONE"
                    ))

                    allPanelItems.append(NotificationItem(
                        id: n.id,
                        source: "linear",
                        type: humanReadableType(n.type),
                        title: issue.title,
                        url: issue.url,
                        identifier: issue.identifier,
                        isUnread: isUnread,
                        createdAt: n.createdAt
                    ))
                }

                // Queue native notifications for new items only
                for n in newItems {
                    guard let issue = n.issue else { continue }
                    nativeItems.append((
                        title: "Linear: \(humanReadableType(n.type))",
                        body: "\(issue.identifier) \(issue.title)",
                        id: n.id
                    ))
                }
            }
        }

        // 2. Detect new Pylon issues
        if pylonEnabled {
            if let apiKey = KeychainHelper.loadToken(for: "pylon-api-token") {
                log("Notifications: checking for new Pylon issues...")
                let client = PylonAPIClient(apiKey: apiKey)
                let allIssues = try await client.fetchAllRecentIssues()
                let validStates: Set<String> = ["new", "waiting_on_you"]
                let issues = allIssues.filter { validStates.contains($0.state) }

                let newIssues = notifService.processNewPylonIssues(issues)
                log("Notifications: \(newIssues.count) new Pylon issues")

                for issue in newIssues {
                    nativeItems.append((
                        title: "Pylon: New Issue",
                        body: "#\(issue.number) \(issue.title)",
                        id: issue.id
                    ))

                    allPanelItems.append(NotificationItem(
                        id: issue.id,
                        source: "pylon",
                        type: "New Issue",
                        title: issue.title,
                        url: "https://app.usepylon.com/issues?issueNumber=\(issue.number)",
                        identifier: "#\(issue.number)",
                        isUnread: true,
                        createdAt: nil
                    ))
                }
            }
        }

        // 3. Write notifications digest
        if !allDigestItems.isEmpty {
            log("Notifications: writing \(allDigestItems.count) items to notifications.md")
            try writer.writeNotifications(items: allDigestItems)
        }

        // 4. Update in-memory items (filters dismissed)
        notifService.updateItems(allPanelItems)

        // 5. Deliver native notifications
        if !nativeItems.isEmpty {
            log("Notifications: delivering \(nativeItems.count) native notifications")
            notifService.deliverNativeNotifications(items: nativeItems)
        }

        lastNotificationSync = Date()
        log("Notifications: sync complete")
    }

    private func humanReadableType(_ type: String) -> String {
        switch type {
        case "issueAssignment": return "Assigned"
        case "issueComment": return "Comment"
        case "issueMention": return "Mention"
        case "issueStatusChanged": return "Status Changed"
        case "issuePriorityChanged": return "Priority Changed"
        case "issueNewComment": return "New Comment"
        default: return type
        }
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
