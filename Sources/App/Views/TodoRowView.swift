import AppKit
import SwiftUI
import Models

struct TodoRowView: View {
    let item: TodoItem
    var onToggle: () -> Void
    var onSetMarker: (TaskMarker) -> Void

    @State private var isHovered = false

    private var isCompleted: Bool {
        item.marker.isCompleted
    }

    /// Tags to display, filtering out source-related tags already shown via the badge
    private var displayTags: [String] {
        let hiddenTags: Set<String> = ["linear", "pylon"]
        return item.tags.filter { !hiddenTags.contains($0.lowercased()) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Status icon button
            Button(action: onToggle) {
                Image(systemName: item.marker.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(item.marker.color)
            }
            .buttonStyle(.plain)
            .help("Toggle status")
            .accessibilityLabel("\(item.marker.displayName): \(item.content)")
            .accessibilityHint("Double tap to change status to \(item.marker.nextStatus.displayName)")

            VStack(alignment: .leading, spacing: 2) {
                // Main content line
                HStack(spacing: 4) {
                    if item.priority != .none {
                        Circle()
                            .fill(item.priority.color)
                            .frame(width: 6, height: 6)
                            .help("Priority: \(item.priority.displayName)")
                            .accessibilityLabel("Priority: \(item.priority.displayName)")
                    }

                    if let url = item.sourceURL {
                        Text(item.content)
                            .font(.system(size: 12))
                            .foregroundColor(isCompleted ? .secondary : .blue)
                            .strikethrough(isCompleted)
                            .opacity(isCompleted ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: isCompleted)
                            .lineLimit(2)
                            .onTapGesture { NSWorkspace.shared.open(url) }
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .help("Open in \(item.source.displayName)")
                    } else {
                        Text(item.content)
                            .font(.system(size: 12))
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                            .opacity(isCompleted ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: isCompleted)
                            .lineLimit(2)
                    }
                }

                // Metadata row
                HStack(spacing: 4) {
                    // Source badge (only for digest items) — clickable if URL available
                    if item.source != .manual {
                        if let url = item.sourceURL {
                            Label(item.source.displayName, systemImage: item.source.iconName)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(item.source.color.opacity(0.12))
                                .foregroundStyle(item.source.color)
                                .clipShape(Capsule())
                                .onTapGesture { NSWorkspace.shared.open(url) }
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                                .help("Open in \(item.source.displayName)")
                                .accessibilityLabel("Source: \(item.source.displayName)")
                        } else {
                            Label(item.source.displayName, systemImage: item.source.iconName)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(item.source.color.opacity(0.12))
                                .foregroundStyle(item.source.color)
                                .clipShape(Capsule())
                                .accessibilityLabel("Source: \(item.source.displayName)")
                        }
                    }

                    // Tags (skip source-related tags since we show the badge)
                    ForEach(displayTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    // Page references
                    ForEach(item.pageRefs, id: \.self) { ref in
                        Text(ref)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.12))
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

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        )
        .accessibilityElement(children: .combine)
        .contextMenu {
            ForEach(TaskMarker.allCases) { marker in
                Button {
                    onSetMarker(marker)
                } label: {
                    Label(marker.displayName, systemImage: marker.iconName)
                }
                .disabled(marker == item.marker)
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
                Label("Copy Content", systemImage: "doc.on.doc")
            }
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
