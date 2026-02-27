import SwiftUI
import Models
import Services
import Networking
import UserNotifications

// MARK: - Bridge Services.DigestFileManager to Networking.DigestWriter

extension DigestFileManager: DigestWriter {
    public func writeDigest(source: String, items: [DigestItem]) throws {
        let lines = items.map { item in
            buildSourceLine(
                text: item.text,
                source: source,
                sourceId: item.sourceId,
                url: item.url,
                identifier: item.identifier,
                priority: item.priority,
                status: item.status
            )
        }
        syncItems(source: source, lines: lines)
    }

    public func writeNotifications(items: [DigestItem]) throws {
        let lines = items.map { item in
            buildSourceLine(
                text: item.text,
                source: "notification",
                sourceId: item.sourceId,
                url: item.url,
                identifier: item.identifier,
                priority: item.priority,
                status: item.status
            )
        }
        writeNotifications(lines: lines)
    }
}

// MARK: - Notification Delegate

/// Allows macOS notification banners to appear even when the app is in the foreground.
/// Must be a static singleton because UNUserNotificationCenter.delegate is weak.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

// MARK: - App

struct NotaNoteApp: App {
    @State private var viewModel: TodoListViewModel
    @State private var gitService: GitSyncService
    @State private var syncService: APISyncService
    @State private var notificationService: NotificationService
    @AppStorage("menuBarIcon") private var menuBarIcon: String = "checkmark"

    init() {
        // Preload keychain tokens so there's at most one unlock prompt
        KeychainHelper.preloadTokens(accounts: ["linear-api-token", "pylon-api-token"])

        let defaultPath = UserDefaults.standard.string(forKey: "logseq.graphPath") ?? "/Users/ogge/repos/notes"
        let store = TodoStore(graphPath: defaultPath)
        _viewModel = State(initialValue: TodoListViewModel(store: store))

        let git = GitSyncService()
        _gitService = State(initialValue: git)

        let notifService = NotificationService()
        _notificationService = State(initialValue: notifService)

        let sync = APISyncService()
        let digestManager = DigestFileManager(graphPath: store.graphPath)
        sync.configure(digestWriter: digestManager, notificationService: notifService)
        _syncService = State(initialValue: sync)

        // Wire services into the settings window controller
        SettingsWindowController.shared.gitService = git
        SettingsWindowController.shared.syncService = sync

        // Detect git status for the current graph path
        let effectivePath = store.graphPath
        git.detectGitStatus(at: effectivePath)

        // Start periodic git sync if enabled
        if git.enabled {
            git.startPeriodicSync(at: effectivePath)
        }

        // Start periodic API sync if any source is enabled
        if sync.linearEnabled || sync.pylonEnabled {
            sync.startPeriodicSync()
        }

        // Request notification permissions and set delegate for foreground delivery
        // Use static singleton so the weak delegate reference isn't lost
        notifService.requestPermissionIfNeeded()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView(viewModel: viewModel, syncService: syncService, notificationService: notificationService)
                .onReceive(NotificationCenter.default.publisher(for: .apiSyncRequested)) { _ in
                    Task {
                        await syncService.syncAll()
                        viewModel.store.reload()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .apiSyncCompleted)) { _ in
                    viewModel.store.reload()
                    // Push digest changes to git after API sync
                    if gitService.enabled && gitService.isGitRepo {
                        Task {
                            await gitService.commitAndPush(at: viewModel.store.graphPath)
                        }
                    }
                }
                .onAppear {
                    notificationService.clearBadge()
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        let badge = notificationService.unreadCount > 0 ? " \u{2022}" : ""
        switch menuBarIcon {
        case "not":
            customMenuBarLabel(imageName: "menubar-not", badge: badge)
        case "alt":
            customMenuBarLabel(imageName: "menubar-alt", badge: badge)
        default:
            Label("\(viewModel.activeTodoCount)\(badge)", systemImage: "checkmark.circle")
        }
    }

    @ViewBuilder
    private func customMenuBarLabel(imageName: String, badge: String) -> some View {
        if let img = loadTemplateImage(named: imageName) {
            HStack(spacing: 2) {
                Image(nsImage: img)
                Text("\(viewModel.activeTodoCount)\(badge)")
            }
        } else {
            Label("\(viewModel.activeTodoCount)\(badge)", systemImage: "checkmark.circle")
        }
    }

    private func loadTemplateImage(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }
}
