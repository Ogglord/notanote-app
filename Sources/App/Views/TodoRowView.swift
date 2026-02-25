import AppKit
import SwiftUI
import Models

struct TodoRowView: View {
    let item: TodoItem
    var onToggle: () -> Void
    var onSetMarker: (TaskMarker) -> Void
    var onSetPriority: (TaskPriority) -> Void
    var onUpdateContent: (String) -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isEditFocused: Bool

    private var isCompleted: Bool {
        item.marker.isCompleted
    }

    /// Tags to display, filtering out source-related tags already shown via the badge
    private var displayTags: [String] {
        let hiddenTags: Set<String> = ["linear", "pylon"]
        return item.tags.filter { !hiddenTags.contains($0.lowercased()) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Status icon button — larger click target
            Button(action: onToggle) {
                Image(systemName: item.marker.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(item.marker.color)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Toggle status")
            .accessibilityLabel("\(item.marker.displayName): \(item.content)")
            .accessibilityHint("Double tap to change status to \(item.marker.nextStatus.displayName)")

            VStack(alignment: .leading, spacing: 3) {
                // Main content line
                HStack(spacing: 4) {
                    if item.priority != .none {
                        Circle()
                            .fill(item.priority.color)
                            .frame(width: 6, height: 6)
                            .help("Priority: \(item.priority.displayName)")
                            .accessibilityLabel("Priority: \(item.priority.displayName)")
                    }

                    if isEditing {
                        TextField("", text: $editText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .focused($isEditFocused)
                            .onSubmit { commitEdit() }
                            .onExitCommand { cancelEdit() }
                    } else {
                        Text(item.content)
                            .font(.system(size: 12))
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                            .opacity(isCompleted ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: isCompleted)
                            .lineLimit(2)
                    }

                    // External link icon on hover for linked items
                    if item.sourceURL != nil && isHovered && !isEditing {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .transition(.opacity)
                    }
                }

                // Metadata row
                if hasMetadata {
                    HStack(spacing: 4) {
                        // Source badge (only for digest items) — clickable if URL available
                        if item.source != .manual {
                            sourceBadge
                        }

                        // Tags
                        ForEach(displayTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.08))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }

                        // Page references
                        ForEach(item.pageRefs, id: \.self) { ref in
                            Text(ref)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.purple.opacity(0.08))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }

                        // Scheduled date
                        if let scheduled = item.scheduledDate {
                            Label(formattedDate(scheduled), systemImage: "calendar")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        // Deadline
                        if let deadline = item.deadline {
                            Label(formattedDate(deadline), systemImage: "exclamationmark.circle")
                                .font(.system(size: 9))
                                .foregroundStyle(item.isOverdue ? .red : .secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            // Three-dot menu — shown on hover
            if isHovered && !isEditing {
                itemMenu
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        )
        .onTapGesture {
            if !isEditing, let url = item.sourceURL {
                NSWorkspace.shared.open(url)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Three-dot Menu

    private var itemMenu: some View {
        Menu {
            Button {
                startEditing()
            } label: {
                Label("Edit Text", systemImage: "pencil")
            }

            Divider()

            Menu("Status") {
                ForEach(TaskMarker.allCases) { marker in
                    Button {
                        onSetMarker(marker)
                    } label: {
                        HStack {
                            Label(marker.displayName, systemImage: marker.iconName)
                            if marker == item.marker {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(marker == item.marker)
                }
            }

            Menu("Priority") {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button {
                        onSetPriority(priority)
                    } label: {
                        HStack {
                            if priority != .none {
                                Image(systemName: "circle.fill")
                                    .foregroundStyle(priority.color)
                                    .imageScale(.small)
                            }
                            Text(priority.displayName)
                            if priority == item.priority {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(priority == item.priority)
                }
            }

            Divider()

            if let url = item.sourceURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open in \(item.source.displayName)", systemImage: "arrow.up.forward.app")
                }
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.content, forType: .string)
            } label: {
                Label("Copy Text", systemImage: "doc.on.doc")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Actions")
    }

    // MARK: - Editing

    private func startEditing() {
        editText = item.content
        isEditing = true
        // Focus after a brief delay to let the view update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isEditFocused = true
        }
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != item.content {
            onUpdateContent(trimmed)
        }
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
    }

    // MARK: - Helpers

    private var hasMetadata: Bool {
        item.source != .manual || !displayTags.isEmpty || !item.pageRefs.isEmpty
            || item.scheduledDate != nil || item.deadline != nil
    }

    @ViewBuilder
    private var sourceBadge: some View {
        let badge = Label(item.source.displayName, systemImage: item.source.iconName)
            .font(.system(size: 9))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(item.source.color.opacity(0.08))
            .foregroundStyle(item.source.color)
            .clipShape(Capsule())
            .accessibilityLabel("Source: \(item.source.displayName)")

        if let url = item.sourceURL {
            badge
                .onTapGesture { NSWorkspace.shared.open(url) }
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .help("Open in \(item.source.displayName)")
        } else {
            badge
        }
    }

    private func formattedDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
