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

    /// Show just the last folder name for a cleaner display
    private var folderName: String {
        (effectivePath as NSString).lastPathComponent
    }

    var body: some View {
        Section("Notes Folder") {
            if isStandaloneMode {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Standalone mode")
                            .font(.system(size: 12, weight: .medium))
                        Text(effectivePath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Connect Folder...") {
                        selectGraphFolder()
                    }
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(graphPathValid ? .blue : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folderName)
                            .font(.system(size: 12, weight: .medium))
                        Text(graphPath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    if graphPathValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))
                            .help("Connected")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                            .help("journals/ folder not found")
                    }
                }

                HStack {
                    Button("Change...") {
                        selectGraphFolder()
                    }
                    .controlSize(.small)

                    Button("Disconnect") {
                        graphPath = ""
                    }
                    .controlSize(.small)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func selectGraphFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your notes folder"
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

extension StorageSettingsSection {
    func onAppear() {
        validatePath()
    }
}
