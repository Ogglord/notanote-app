import SwiftUI
import Models

struct FilterBarView: View {
    @Binding var filterMode: FilterMode
    @Binding var sourceFilter: TodoSource?
    var sourceCounts: [TodoSource: Int]

    var body: some View {
        VStack(spacing: 6) {
            // Filter mode segmented picker
            Picker("Filter", selection: $filterMode) {
                ForEach(FilterMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Source filter pills
            HStack(spacing: 4) {
                sourceFilterButton(nil, label: "All", icon: "tray.full")
                ForEach(TodoSource.allCases) { source in
                    sourceFilterButton(source, label: source.displayName, icon: source.iconName)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func sourceFilterButton(_ source: TodoSource?, label: String, icon: String) -> some View {
        let isSelected = sourceFilter == source
        let count = source.map { sourceCounts[$0] ?? 0 } ?? sourceCounts.values.reduce(0, +)
        let accentColor: Color = source?.color ?? .secondary

        SourcePillButton(
            icon: icon,
            count: count,
            isSelected: isSelected,
            accentColor: accentColor,
            helpText: source?.displayName ?? "All sources"
        ) {
            withAnimation(.easeInOut(duration: 0.15)) {
                sourceFilter = source
            }
        }
    }
}

/// Extracted pill button to hold its own hover state
private struct SourcePillButton: View {
    let icon: String
    let count: Int
    let isSelected: Bool
    let accentColor: Color
    let helpText: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .contentTransition(.numericText())
                    .animation(.default, value: count)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isSelected ? accentColor.opacity(0.15) : (isHovered ? accentColor.opacity(0.07) : .clear))
            .foregroundStyle(isSelected ? accentColor : (isHovered ? accentColor : .secondary))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? accentColor.opacity(0.3) : .clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { isHovered = $0 }
    }
}
