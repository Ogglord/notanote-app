import SwiftUI
import Models

struct TodoSectionView: View {
    let group: TodoGroup
    var onToggle: (TodoItem) -> Void
    var onSetMarker: (TodoItem, TaskMarker) -> Void
    var focusedItemId: FocusState<String?>.Binding

    @State private var isExpanded: Bool

    init(
        group: TodoGroup,
        onToggle: @escaping (TodoItem) -> Void,
        onSetMarker: @escaping (TodoItem, TaskMarker) -> Void,
        focusedItemId: FocusState<String?>.Binding
    ) {
        self.group = group
        self.onToggle = onToggle
        self.onSetMarker = onSetMarker
        self.focusedItemId = focusedItemId
        // Expand by default unless all items are completed
        let allCompleted = group.items.allSatisfy { $0.marker.isCompleted }
        _isExpanded = State(initialValue: !allCompleted)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(group.items) { item in
                TodoRowView(
                    item: item,
                    onToggle: { onToggle(item) },
                    onSetMarker: { marker in onSetMarker(item, marker) }
                )
                .focused(focusedItemId, equals: item.id)
                if item.id != group.items.last?.id {
                    Divider()
                        .padding(.leading, 20)
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let icon = group.icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text(group.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(group.items.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary)
                    .clipShape(Capsule())
                    .contentTransition(.numericText())
                    .animation(.default, value: group.items.count)
            }
        }
    }
}
