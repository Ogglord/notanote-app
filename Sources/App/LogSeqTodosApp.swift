import SwiftUI
import Models
import Services

struct LogSeqTodosApp: App {
    @State private var viewModel: TodoListViewModel
    @State private var gitService: GitSyncService

    init() {
        let defaultPath = UserDefaults.standard.string(forKey: "logseq.graphPath") ?? "/Users/ogge/repos/notes"
        let store = TodoStore(graphPath: defaultPath)
        _viewModel = State(initialValue: TodoListViewModel(store: store))

        let git = GitSyncService()
        _gitService = State(initialValue: git)

        // Wire the git service into the settings window controller
        SettingsWindowController.shared.gitService = git

        // Detect git status for the current graph path
        let effectivePath = store.graphPath
        git.detectGitStatus(at: effectivePath)

        // Start periodic git sync if enabled
        if git.enabled {
            git.startPeriodicSync(at: effectivePath)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView(viewModel: viewModel)
        } label: {
            Label("\(viewModel.activeTodoCount)", systemImage: "checkmark.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
