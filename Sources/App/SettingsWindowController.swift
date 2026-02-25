import AppKit
import SwiftUI
import Services
import Networking

/// Manages a standalone NSWindow for settings in a menubar-only app.
/// SwiftUI's `Settings` scene doesn't work reliably with LSUIElement apps,
/// so we manage the window ourselves.
///
/// When the settings window is open, the app temporarily becomes a regular app
/// (visible in Cmd+Tab / Dock) so text fields work properly and the window
/// is easy to find. When closed, it reverts to an agent (menu-bar-only) app.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    var gitService: GitSyncService?
    var syncService: APISyncService?

    private var window: NSWindow?

    func open() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Become a regular app so the window appears in Cmd+Tab and text fields work
        NSApp.setActivationPolicy(.regular)

        // Set the Dock / Cmd+Tab icon from bundled resources
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns", subdirectory: "Resources") {
            NSApp.applicationIconImage = NSImage(contentsOf: iconURL)
        }

        let settingsView = SettingsView(
            gitService: gitService ?? GitSyncService(),
            syncService: syncService ?? APISyncService()
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "NotaNote Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 640, height: 480))
        window.minSize = NSSize(width: 640, height: 460)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.window = window

        // Dismiss the MenuBarExtra popover before showing settings
        for w in NSApp.windows where w !== window && w.isVisible {
            w.orderOut(nil)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Revert to agent app (menu-bar-only, no Dock icon)
        NSApp.setActivationPolicy(.accessory)
    }
}
