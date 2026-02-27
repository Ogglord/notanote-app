import SwiftUI

struct NotificationSettingsSection: View {
    @AppStorage("notifications.enabled") private var enabled: Bool = true
    @AppStorage("notifications.native") private var nativeEnabled: Bool = true

    var body: some View {
        Section("Notifications") {
            Toggle("Enable notification sync", isOn: $enabled)

            if enabled {
                Toggle("Show macOS notification banners", isOn: $nativeEnabled)

                Text("Syncs your Linear inbox (last 10 entries) and detects new Pylon issues each sync cycle. New items trigger macOS notifications and show a badge on the menu bar icon.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
