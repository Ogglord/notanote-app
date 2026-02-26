import SwiftUI
import Models

struct TodoSectionView: View {
    let group: TodoGroup
    @Binding var isEditingItem: Bool
    var onToggle: (TodoItem) -> Void
    var onSetMarker: (TodoItem, TaskMarker) -> Void
    var onSetPriority: (TodoItem, TaskPriority) -> Void
    var onSetDeadline: (TodoItem, Date?) -> Void
    var onUpdateContent: (TodoItem, String) -> Void
    var focusedItemId: FocusState<String?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Lightweight section header
            HStack {
                Text(group.title.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)

                Spacer()

                Text("\(group.items.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                    .contentTransition(.numericText())
                    .animation(.default, value: group.items.count)
            }
            .padding(.horizontal, 4)
            .padding(.top, 12)
            .padding(.bottom, 4)

            // Items
            ForEach(group.items) { item in
                TodoRowView(
                    item: item,
                    isEditingItem: $isEditingItem,
                    onToggle: { onToggle(item) },
                    onSetMarker: { marker in onSetMarker(item, marker) },
                    onSetPriority: { priority in onSetPriority(item, priority) },
                    onSetDeadline: { date in onSetDeadline(item, date) },
                    onUpdateContent: { text in onUpdateContent(item, text) }
                )
                .focused(focusedItemId, equals: item.id)
            }
        }
    }
}
