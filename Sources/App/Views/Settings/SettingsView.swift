import SwiftUI
import Models
import Services
import Networking

struct SettingsView: View {
    @Bindable var gitService: GitSyncService
    @AppStorage("graphPath") private var graphPath: String = ""

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }

            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            LinearTab()
                .tabItem { Label("Linear", systemImage: "arrow.triangle.branch") }

            PylonTab()
                .tabItem { Label("Pylon", systemImage: "message") }

            GitSyncTab(gitService: gitService, graphPath: effectiveGraphPath)
                .tabItem { Label("Git Sync", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 500, height: 420)
    }

    private var effectiveGraphPath: String {
        graphPath.isEmpty
            ? NSHomeDirectory() + "/.logseq-todos"
            : graphPath
    }
}

// MARK: - General

private struct GeneralTab: View {
    var body: some View {
        Form {
            StorageSettingsSection()
            SyncScheduleSection()
            Section {
                Button("Quit LogSeq Todos") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    var body: some View {
        Form {
            DisplaySettingsSection()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Linear

private struct LinearTab: View {
    var body: some View {
        Form {
            LinearSettingsSection()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Pylon

private struct PylonTab: View {
    var body: some View {
        Form {
            PylonSettingsSection()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Git Sync

private struct GitSyncTab: View {
    @Bindable var gitService: GitSyncService
    var graphPath: String

    var body: some View {
        Form {
            GitSyncSettingsSection(gitService: gitService, graphPath: graphPath)
        }
        .formStyle(.grouped)
    }
}
