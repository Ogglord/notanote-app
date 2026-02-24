import AppKit
import SwiftUI
import Services

/// Manages a standalone NSWindow for settings in a menubar-only app.
/// SwiftUI's `Settings` scene doesn't work reliably with LSUIElement apps,
/// so we manage the window ourselves.
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    var gitService: GitSyncService?

    private var window: NSWindow?

    func open() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            gitService: gitService ?? GitSyncService()
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "LogSeq Todos Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 440))
        window.center()
        window.isReleasedWhenClosed = false

        self.window = window

        // Dismiss the MenuBarExtra popover before showing settings
        for w in NSApp.windows where w !== window && w.isVisible {
            w.orderOut(nil)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
