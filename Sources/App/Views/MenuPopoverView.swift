import SwiftUI
import Models
import Services

struct MenuPopoverView: View {
    @Bindable var viewModel: TodoListViewModel
    @State private var newTodoText: String = ""
    @FocusState private var isAddFieldFocused: Bool
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var focusedItemId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Add new todo
            addTodoBar

            Divider()

            // Filter bar
            FilterBarView(
                filterMode: $viewModel.filterMode,
                sourceFilter: $viewModel.sourceFilter,
                sourceCounts: viewModel.sourceCounts
            )

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search todos...", text: $viewModel.searchText)
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
                            .foregroundStyle(.secondary)
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

            Divider()

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
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if viewModel.groupMode == .flat {
                            ForEach(viewModel.filteredItems) { item in
                                TodoRowView(
                                    item: item,
                                    onToggle: { viewModel.toggleTask(item) },
                                    onSetMarker: { marker in viewModel.setMarker(item, to: marker) }
                                )
                                .focused($focusedItemId, equals: item.id)
                                if item.id != viewModel.filteredItems.last?.id {
                                    Divider()
                                        .padding(.leading, 24)
                                }
                            }
                        } else {
                            ForEach(viewModel.groupedItems) { group in
                                TodoSectionView(
                                    group: group,
                                    onToggle: { item in viewModel.toggleTask(item) },
                                    onSetMarker: { item, marker in viewModel.setMarker(item, to: marker) },
                                    focusedItemId: $focusedItemId
                                )
                                .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .animation(.default, value: viewModel.filterMode)
                .animation(.default, value: viewModel.groupMode)
                .animation(.default, value: viewModel.searchText)
            }

            Divider()

            // Bottom bar
            HStack {
                Text("\(viewModel.activeTodoCount) active")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.default, value: viewModel.activeTodoCount)

                if let lastUpdated = viewModel.store.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative) ago")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    viewModel.store.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Refresh")
                .accessibilityLabel("Refresh todos")

                Button {
                    SettingsWindowController.shared.open()
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Settings")
                .accessibilityLabel("Open settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 380)
        .frame(minHeight: 600, maxHeight: 1000)
        .background(.ultraThinMaterial)
        .onAppear { isAddFieldFocused = true }
        .onKeyPress(.upArrow) { moveFocus(direction: -1); return .handled }
        .onKeyPress(.downArrow) { moveFocus(direction: 1); return .handled }
        .onKeyPress(.return) { toggleFocusedItem(); return .handled }
        .onKeyPress(.space) { toggleFocusedItem(); return .handled }
        .onKeyPress(.escape) { handleEscape(); return .handled }
        // Hidden buttons to anchor keyboard shortcuts
        .background {
            Group {
                Button("") { isAddFieldFocused = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("") { isSearchFieldFocused = true }
                    .keyboardShortcut("f", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Add Todo Bar

    private var addTodoBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.blue)

            TextField("Add a todo to today's journal...", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isAddFieldFocused)
                .accessibilityLabel("Add new todo")
                .accessibilityHint("Type a todo and press return to add it")
                .onSubmit {
                    submitNewTodo()
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
                .help("Press Return to add")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.05))
    }

    private func submitNewTodo() {
        let text = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.addTodo(text)
        newTodoText = ""
        isAddFieldFocused = true
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
            isAddFieldFocused = true
        }
    }
}
