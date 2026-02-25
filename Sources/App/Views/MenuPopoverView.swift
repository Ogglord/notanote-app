import SwiftUI
import Models
import Services
import Networking

struct MenuPopoverView: View {
    @Bindable var viewModel: TodoListViewModel
    var syncService: APISyncService
    @State private var newTodoText: String = ""
    @State private var isSearchVisible: Bool = false
    @State private var isSyncLogVisible: Bool = false
    @FocusState private var isAddFieldFocused: Bool
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var focusedItemId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Add new todo
            addTodoBar

            // Filter bar
            FilterBarView(
                filterMode: $viewModel.filterMode,
                sourceFilter: $viewModel.sourceFilter,
                sourceCounts: viewModel.sourceCounts
            )

            // Search field — hidden by default, toggle via Cmd+F or button
            if isSearchVisible {
                searchBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Main content
            if viewModel.store.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            } else if viewModel.groupedItems.isEmpty {
                Spacer()
                emptyStateView
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if viewModel.groupMode == .flat {
                            ForEach(viewModel.filteredItems) { item in
                                TodoRowView(
                                    item: item,
                                    onToggle: { viewModel.toggleTask(item) },
                                    onSetMarker: { marker in viewModel.setMarker(item, to: marker) },
                                    onSetPriority: { priority in viewModel.updatePriority(item, to: priority) },
                                    onUpdateContent: { text in viewModel.updateContent(item, newContent: text) }
                                )
                                .focused($focusedItemId, equals: item.id)
                            }
                        } else {
                            ForEach(viewModel.groupedItems) { group in
                                TodoSectionView(
                                    group: group,
                                    onToggle: { item in viewModel.toggleTask(item) },
                                    onSetMarker: { item, marker in viewModel.setMarker(item, to: marker) },
                                    onSetPriority: { item, priority in viewModel.updatePriority(item, to: priority) },
                                    onUpdateContent: { item, text in viewModel.updateContent(item, newContent: text) },
                                    focusedItemId: $focusedItemId
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
                .animation(.default, value: viewModel.filterMode)
                .animation(.default, value: viewModel.groupMode)
                .animation(.default, value: viewModel.searchText)
            }

            Divider()

            // Expandable sync log
            if isSyncLogVisible {
                syncLogPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Bottom bar
            bottomBar
        }
        .frame(width: 380)
        .frame(minHeight: 600, maxHeight: 1000)
        .background(.ultraThinMaterial)
        .onAppear { isAddFieldFocused = true }
        .onChange(of: syncService.lastError) {
            // Auto-show log when an error occurs
            if syncService.lastError != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSyncLogVisible = true
                }
            }
        }
        .onKeyPress(.upArrow) { moveFocus(direction: -1); return .handled }
        .onKeyPress(.downArrow) { moveFocus(direction: 1); return .handled }
        .onKeyPress(.return) {
            guard !isAddFieldFocused && !isSearchFieldFocused else { return .ignored }
            toggleFocusedItem(); return .handled
        }
        .onKeyPress(.space) {
            guard !isAddFieldFocused && !isSearchFieldFocused else { return .ignored }
            toggleFocusedItem(); return .handled
        }
        .onKeyPress(.escape) { handleEscape(); return .handled }
        // Hidden buttons to anchor keyboard shortcuts
        .background {
            Group {
                Button("") { isAddFieldFocused = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("") { toggleSearch() }
                    .keyboardShortcut("f", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Add Todo Bar

    private var addTodoBar: some View {
        HStack(spacing: 8) {
            Text("+")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.blue)

            ZStack(alignment: .leading) {
                if newTodoText.isEmpty {
                    Text("New todo...")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                TextField("", text: $newTodoText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isAddFieldFocused)
                    .accessibilityLabel("Add new todo")
                    .accessibilityHint("Type a todo and press return to add it")
                    .onSubmit {
                        submitNewTodo()
                    }
            }

            if !newTodoText.isEmpty {
                Button {
                    submitNewTodo()
                } label: {
                    Image(systemName: "return")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Press Return to add (⌘N)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Search...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFieldFocused)
                .accessibilityLabel("Search todos")
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.activeTodoCount) active")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.default, value: viewModel.activeTodoCount)

            // Sync status — clickable to toggle log
            if syncService.isSyncing || syncService.lastSyncDate != nil || syncService.lastError != nil {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSyncLogVisible.toggle()
                    }
                } label: {
                    syncStatusLabel
                }
                .buttonStyle(.plain)
                .help(isSyncLogVisible ? "Hide sync log" : "Show sync log")
            }

            Spacer()

            // Search toggle
            Button {
                toggleSearch()
            } label: {
                Image(systemName: isSearchVisible ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(isSearchVisible ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help("Search (⌘F)")
            .accessibilityLabel("Toggle search")

            // Settings menu
            Menu {
                Button {
                    viewModel.store.reload()
                } label: {
                    Label("Reload Data", systemImage: "arrow.clockwise")
                }

                Divider()

                Button {
                    SettingsWindowController.shared.open()
                } label: {
                    Label("Settings...", systemImage: "gearshape")
                }

                Divider()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit NotaNote")
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Menu")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Sync Status

    @ViewBuilder
    private var syncStatusLabel: some View {
        if syncService.isSyncing {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.6)
                    .frame(width: 10, height: 10)
                Text("Syncing…")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        } else if syncService.lastError != nil {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                Text("Sync error")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        } else if let lastSync = syncService.lastSyncDate {
            HStack(spacing: 3) {
                Text(syncSummary(lastSync: lastSync))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Image(systemName: isSyncLogVisible ? "chevron.down" : "chevron.right")
                    .font(.system(size: 7))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    private func syncSummary(lastSync: Date) -> String {
        let ago = relativeTime(since: lastSync)
        var parts: [String] = []
        if syncService.lastLinearCount > 0 {
            parts.append("\(syncService.lastLinearCount) Linear")
        }
        if syncService.lastPylonCount > 0 {
            parts.append("\(syncService.lastPylonCount) Pylon")
        }
        if parts.isEmpty {
            return ago
        }
        return "\(ago) · \(parts.joined(separator: ", "))"
    }

    private func relativeTime(since date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }

    // MARK: - Sync Log Panel

    private var syncLogPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SYNC LOG")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSyncLogVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(syncService.syncLog.enumerated()), id: \.offset) { idx, entry in
                            Text(entry)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(logEntryColor(entry))
                                .textSelection(.enabled)
                                .id(idx)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .onChange(of: syncService.syncLog.count) {
                    if let last = syncService.syncLog.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .frame(height: 100)

            Divider()
        }
        .background(.black.opacity(0.03))
    }

    private func logEntryColor(_ entry: String) -> Color {
        if entry.contains("ERROR") || entry.contains("failed") {
            return .red
        } else if entry.contains("✗") {
            return .orange
        } else {
            return .secondary
        }
    }

    // MARK: - Actions

    private func submitNewTodo() {
        let text = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.addTodo(text)
        newTodoText = ""
        isAddFieldFocused = true
    }

    private func toggleSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearchVisible.toggle()
        }
        if isSearchVisible {
            isSearchFieldFocused = true
        } else {
            viewModel.searchText = ""
            isAddFieldFocused = true
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No matching todos")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Try adjusting your filters or search.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Keyboard Navigation

    private var allVisibleItems: [TodoItem] {
        if viewModel.groupMode == .flat {
            return viewModel.filteredItems
        } else {
            return viewModel.groupedItems.flatMap(\.items)
        }
    }

    private func moveFocus(direction: Int) {
        let items = allVisibleItems
        guard !items.isEmpty else { return }

        guard let currentId = focusedItemId,
              let currentIndex = items.firstIndex(where: { $0.id == currentId }) else {
            focusedItemId = items.first?.id
            return
        }

        let newIndex = currentIndex + direction
        if newIndex >= 0 && newIndex < items.count {
            focusedItemId = items[newIndex].id
        }
    }

    private func toggleFocusedItem() {
        guard let currentId = focusedItemId,
              let item = allVisibleItems.first(where: { $0.id == currentId }) else { return }
        viewModel.toggleTask(item)
    }

    private func handleEscape() {
        if isSearchFieldFocused || !viewModel.searchText.isEmpty {
            viewModel.searchText = ""
            isSearchFieldFocused = false
            isSearchVisible = false
            isAddFieldFocused = true
        }
    }
}
