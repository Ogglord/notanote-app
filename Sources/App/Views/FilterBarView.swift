import SwiftUI
import Models

struct FilterBarView: View {
    @Binding var filterMode: FilterMode
    @Binding var sourceFilter: TodoSource?
    var sourceCounts: [TodoSource: Int]

    var body: some View {
        Picker("Filter", selection: $filterMode) {
            ForEach(FilterMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}
