import Foundation
import Observation
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.notanote", category: "NotificationService")

/// A single notification item displayed in the notification panel.
public struct NotificationItem: Identifiable {
    public let id: String
    public let source: String       // "linear" or "pylon"
    public let type: String         // e.g. "issueAssignment", "New Issue"
    public let title: String        // e.g. "ENG-123 Fix the bug"
    public let url: String?
    public let identifier: String?  // e.g. "ENG-123", "#42"
    public let isUnread: Bool
    public let createdAt: String?
}

/// Tracks seen notification IDs, detects new items, delivers macOS native
/// notifications, and exposes an observable unread count for the menu bar badge.
@Observable
public final class NotificationService {
    // MARK: - Observable State

    public private(set) var unreadCount: Int = 0
    public private(set) var lastNotificationSync: Date?
    public private(set) var items: [NotificationItem] = []

    // MARK: - UserDefaults Keys

    private static let seenLinearKey = "notifications.seenLinearIds"
    private static let seenPylonKey = "notifications.seenPylonIds"
    private static let dismissedKey = "notifications.dismissedIds"

    // MARK: - Settings

    public var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notifications.enabled") }
    }
    public var nativeNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(nativeNotificationsEnabled, forKey: "notifications.native") }
    }

    // MARK: - Init

    public init() {
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notifications.enabled") as? Bool ?? true
        self.nativeNotificationsEnabled = UserDefaults.standard.object(forKey: "notifications.native") as? Bool ?? true
    }

    // MARK: - Permission

    public func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                logger.error("Notification auth error: \(error.localizedDescription)")
            }
            logger.info("Notification permission granted: \(granted)")
        }
    }

    // MARK: - Seen ID Management

    private func loadSeenIds(key: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private func saveSeenIds(_ ids: Set<String>, key: String) {
        // Cap at 200 to prevent unbounded growth
        let array = Array(ids.suffix(200))
        UserDefaults.standard.set(array, forKey: key)
    }

    // MARK: - Dismissed Management

    private func loadDismissedIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? [])
    }

    private func saveDismissedIds(_ ids: Set<String>) {
        let array = Array(ids.suffix(200))
        UserDefaults.standard.set(array, forKey: Self.dismissedKey)
    }

    // MARK: - Process Linear Notifications

    /// Compare fetched notifications against previously seen IDs.
    /// Returns only the new (unseen) notifications.
    public func processLinearNotifications(_ notifications: [LinearNotification]) -> [LinearNotification] {
        var seen = loadSeenIds(key: Self.seenLinearKey)
        let newItems = notifications.filter { !seen.contains($0.id) }
        for n in notifications { seen.insert(n.id) }
        saveSeenIds(seen, key: Self.seenLinearKey)
        return newItems
    }

    // MARK: - Process Pylon Issues

    /// Compare fetched Pylon issues against previously seen IDs.
    /// Returns only the new (unseen) issues.
    public func processNewPylonIssues(_ issues: [PylonIssue]) -> [PylonIssue] {
        var seen = loadSeenIds(key: Self.seenPylonKey)
        let newItems = issues.filter { !seen.contains($0.id) }
        for issue in issues { seen.insert(issue.id) }
        saveSeenIds(seen, key: Self.seenPylonKey)
        return newItems
    }

    // MARK: - Update Items

    /// Replace the in-memory notification items (called after sync), filtering out dismissed.
    public func updateItems(_ newItems: [NotificationItem]) {
        let dismissed = loadDismissedIds()
        items = newItems.filter { !dismissed.contains($0.id) }
        unreadCount = items.filter(\.isUnread).count
    }

    // MARK: - Dismiss

    /// Dismiss a single notification item.
    public func dismiss(_ item: NotificationItem) {
        var dismissed = loadDismissedIds()
        dismissed.insert(item.id)
        saveDismissedIds(dismissed)
        items.removeAll { $0.id == item.id }
        unreadCount = items.filter(\.isUnread).count
    }

    /// Dismiss all notification items.
    public func dismissAll() {
        var dismissed = loadDismissedIds()
        for item in items { dismissed.insert(item.id) }
        saveDismissedIds(dismissed)
        items.removeAll()
        unreadCount = 0
    }

    // MARK: - Deliver Native Notifications

    public func deliverNativeNotifications(items: [(title: String, body: String, id: String)]) {
        guard nativeNotificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()

        for item in items {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "notanote-\(item.id)",
                content: content,
                trigger: nil // deliver immediately
            )
            center.add(request) { error in
                if let error {
                    logger.error("Failed to deliver notification: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Badge

    public func clearBadge() {
        unreadCount = 0
    }
}
