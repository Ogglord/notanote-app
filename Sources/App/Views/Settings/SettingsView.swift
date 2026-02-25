import SwiftUI
import Models
import Services
import Networking

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case appearance
    case linear
    case pylon
    case gitSync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:    return "General"
        case .appearance: return "Appearance"
        case .linear:     return "Linear"
        case .pylon:      return "Pylon"
        case .gitSync:    return "Git Sync"
        }
    }

    var icon: String {
        switch self {
        case .general:    return "gearshape"
        case .appearance: return "paintbrush"
        case .linear:     return "line.3.horizontal.decrease.circle"
        case .pylon:      return "headset.circle"
        case .gitSync:    return "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .general:    return .gray
        case .appearance: return .purple
        case .linear:     return .indigo
        case .pylon:      return .teal
        case .gitSync:    return .orange
        }
    }
}

struct SettingsView: View {
    @Bindable var gitService: GitSyncService
    var syncService: APISyncService
    @AppStorage("graphPath") private var graphPath: String = ""
    @State private var selectedPage: SettingsPage = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $selectedPage) { page in
                Label {
                    Text(page.title)
                } icon: {
                    Image(systemName: page.icon)
                        .foregroundStyle(page.color)
                }
                .tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    detailContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(selectedPage.title)
        }
        .frame(minWidth: 640, minHeight: 460)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedPage {
        case .general:
            Form {
                StorageSettingsSection()
            }
            .formStyle(.grouped)
        case .appearance:
            Form {
                DisplaySettingsSection()
            }
            .formStyle(.grouped)
        case .linear:
            Form {
                LinearSettingsSection()
                SyncScheduleSection(syncService: syncService)
            }
            .formStyle(.grouped)
        case .pylon:
            Form {
                PylonSettingsSection()
                SyncScheduleSection(syncService: syncService)
            }
            .formStyle(.grouped)
        case .gitSync:
            Form {
                GitSyncSettingsSection(gitService: gitService, graphPath: effectiveGraphPath)
            }
            .formStyle(.grouped)
        }
    }

    private var effectiveGraphPath: String {
        graphPath.isEmpty
            ? NSHomeDirectory() + "/.logseq-todos"
            : graphPath
    }
}
