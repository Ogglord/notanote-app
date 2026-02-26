import SwiftUI
import AppKit
import Models

struct DisplaySettingsSection: View {
    @AppStorage("showCompletedTasks") private var showCompletedTasks: Bool = false
    @AppStorage("groupMode") private var groupModeRaw: String = GroupMode.byPage.rawValue
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Double = 2
    @AppStorage("menuBarIcon") private var menuBarIcon: String = "checkmark"
    @AppStorage("secondarySortOrder") private var secondarySortRaw: String = SortOrder.priority.rawValue
    @AppStorage("enabledMarkers") private var enabledMarkersData: Data = {
        let allMarkers = TaskMarker.allCases.map(\.rawValue)
        return (try? JSONEncoder().encode(allMarkers)) ?? Data()
    }()

    @State private var sourceOrder: [TodoSource] = TodoSource.savedOrder

    private var enabledMarkers: Set<String> {
        guard let decoded = try? JSONDecoder().decode([String].self, from: enabledMarkersData) else {
            return Set(TaskMarker.allCases.map(\.rawValue))
        }
        return Set(decoded)
    }

    var body: some View {
        Section("Display") {
            Toggle("Show completed tasks", isOn: $showCompletedTasks)
            Picker("Group by", selection: $groupModeRaw) {
                ForEach(GroupMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.iconName)
                        .tag(mode.rawValue)
                }
            }
            Picker("Menu bar icon", selection: $menuBarIcon) {
                Label("Checkmark", systemImage: "checkmark.circle")
                    .tag("checkmark")
                HStack(spacing: 4) {
                    if let img = menuBarPreviewImage(named: "menubar-not") {
                        Image(nsImage: img)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    Text("NOT mark")
                }
                .tag("not")
                HStack(spacing: 4) {
                    if let img = menuBarPreviewImage(named: "menubar-alt") {
                        Image(nsImage: img)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    Text("N-check")
                }
                .tag("alt")
            }
            HStack {
                Text("Auto-refresh interval")
                Slider(value: $autoRefreshInterval, in: 1...30, step: 1) {
                    Text("Interval")
                }
                Text("\(Int(autoRefreshInterval)) min")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }

        Section("Sorting") {
            Text("Drag to reorder sources. Items from the top source appear first.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            List {
                ForEach(sourceOrder) { source in
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Image(systemName: source.iconName)
                            .font(.system(size: 12))
                            .foregroundStyle(source.color)
                            .frame(width: 16)
                        Text(source.displayName)
                            .font(.system(size: 12))
                        Spacer()
                        Text("#\(sourceOrder.firstIndex(of: source)! + 1)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 1)
                }
                .onMove { from, to in
                    sourceOrder.move(fromOffsets: from, toOffset: to)
                    TodoSource.saveOrder(sourceOrder)
                }
            }
            .listStyle(.bordered)
            .frame(height: 88)

            Picker("Then sort by", selection: $secondarySortRaw) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.displayName).tag(order.rawValue)
                }
            }
        }

        Section("Visible Task Markers") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(markerRows, id: \.0) { row in
                    HStack(spacing: 16) {
                        ForEach(row.1) { marker in
                            Toggle(isOn: markerBinding(for: marker)) {
                                Label(marker.displayName, systemImage: marker.iconName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(marker.color)
                            }
                            .toggleStyle(.checkbox)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // Pad last row if it has fewer items
                        if row.1.count < 2 {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    /// Markers arranged into rows of 2 for a clean grid
    private var markerRows: [(Int, [TaskMarker])] {
        let markers = TaskMarker.allCases
        var rows: [(Int, [TaskMarker])] = []
        var i = 0
        while i < markers.count {
            let end = min(i + 2, markers.count)
            rows.append((i, Array(markers[i..<end])))
            i += 2
        }
        return rows
    }

    private func menuBarPreviewImage(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources") else { return nil }
        return NSImage(contentsOf: url)
    }

    private func markerBinding(for marker: TaskMarker) -> Binding<Bool> {
        Binding(
            get: { enabledMarkers.contains(marker.rawValue) },
            set: { newValue in
                var current = enabledMarkers
                if newValue {
                    current.insert(marker.rawValue)
                } else {
                    current.remove(marker.rawValue)
                }
                enabledMarkersData = (try? JSONEncoder().encode(Array(current))) ?? Data()
            }
        )
    }
}
