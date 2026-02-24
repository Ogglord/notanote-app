import SwiftUI

struct StorageSettingsSection: View {
    @AppStorage("graphPath") private var graphPath: String = ""
    @State private var graphPathValid: Bool = false

    private var isStandaloneMode: Bool {
        graphPath.isEmpty
    }

    private var effectivePath: String {
        isStandaloneMode
            ? NSHomeDirectory() + "/.logseq-todos"
            : graphPath
    }

    var body: some View {
        Section("Storage") {
            if isStandaloneMode {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.secondary)
                    Text("Standalone mode")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button("Set LogSeq Path") {
                        selectGraphFolder()
                    }
                    .controlSize(.small)
                }
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(effectivePath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                HStack {
                    TextField("Graph path", text: $graphPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    Button("Browse...") {
                        selectGraphFolder()
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: graphPathValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(graphPathValid ? .green : .red)
                        .font(.system(size: 11))
                    Text(graphPathValid ? "Valid graph (journals/ found)" : "Invalid path (journals/ not found)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Button("Switch to standalone mode") {
                    graphPath = ""
                }
                .controlSize(.small)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear { validatePath() }
        .onChange(of: graphPath) { validatePath() }
    }

    private func selectGraphFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your LogSeq graph folder"
        if panel.runModal() == .OK, let url = panel.url {
            graphPath = url.path
        }
    }

    private func validatePath() {
        guard !graphPath.isEmpty else {
            graphPathValid = false
            return
        }
        let journalsPath = (graphPath as NSString).appendingPathComponent("journals")
        var isDir: ObjCBool = false
        graphPathValid = FileManager.default.fileExists(atPath: journalsPath, isDirectory: &isDir) && isDir.boolValue
    }
}
