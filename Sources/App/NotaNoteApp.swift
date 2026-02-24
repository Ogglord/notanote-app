import SwiftUI
import Models
import Services
import Networking

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
}

// MARK: - App

struct NotaNoteApp: App {
    @State private var viewModel: TodoListViewModel
    @State private var gitService: GitSyncService
    @State private var syncService: APISyncService
    @AppStorage("menuBarIcon") private var menuBarIcon: String = "checkmark"

    init() {
        // Preload keychain tokens so there's at most one unlock prompt
        KeychainHelper.preloadTokens(accounts: ["linear-api-token", "pylon-api-token"])

        let defaultPath = UserDefaults.standard.string(forKey: "logseq.graphPath") ?? "/Users/ogge/repos/notes"
        let store = TodoStore(graphPath: defaultPath)
        _viewModel = State(initialValue: TodoListViewModel(store: store))

        let git = GitSyncService()
        _gitService = State(initialValue: git)

        let sync = APISyncService()
        let digestManager = DigestFileManager(graphPath: store.graphPath)
        sync.configure(digestWriter: digestManager)
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
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView(viewModel: viewModel)
                .onReceive(NotificationCenter.default.publisher(for: .apiSyncRequested)) { _ in
                    Task {
                        await syncService.syncAll()
                        viewModel.store.reload()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .apiSyncCompleted)) { _ in
                    viewModel.store.reload()
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        switch menuBarIcon {
        case "not":
            customMenuBarLabel(imageName: "menubar-not")
        case "alt":
            customMenuBarLabel(imageName: "menubar-alt")
        default:
            Label("\(viewModel.activeTodoCount)", systemImage: "checkmark.circle")
        }
    }

    @ViewBuilder
    private func customMenuBarLabel(imageName: String) -> some View {
        if let img = loadTemplateImage(named: imageName) {
            HStack(spacing: 2) {
                Image(nsImage: img)
                Text("\(viewModel.activeTodoCount)")
            }
        } else {
            Label("\(viewModel.activeTodoCount)", systemImage: "checkmark.circle")
        }
    }

    private func loadTemplateImage(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }
}
