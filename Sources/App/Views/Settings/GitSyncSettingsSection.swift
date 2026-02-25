import SwiftUI
import Services

struct GitSyncSettingsSection: View {
    @Bindable var gitService: GitSyncService

    var graphPath: String

    private let intervalOptions: [Double] = [1, 2, 5, 10, 15, 30]

    var body: some View {
        Section("Git Sync") {
            Toggle("Enable automatic git sync", isOn: $gitService.enabled)
                .onChange(of: gitService.enabled) {
                    if gitService.enabled {
                        gitService.startPeriodicSync(at: graphPath)
                    } else {
                        gitService.stopPeriodicSync()
                    }
                }

            if gitService.enabled {
                Picker("Sync interval", selection: $gitService.syncIntervalMinutes) {
                    ForEach(intervalOptions, id: \.self) { min in
                        Text("\(Int(min)) min").tag(min)
                    }
                }
                .pickerStyle(.menu)

                TextField("Commit message template", text: $gitService.commitMessageTemplate)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                Text("Use {date} for the current timestamp.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // Status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(gitService.isGitRepo ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(gitService.isGitRepo ? "Git repository detected" : "Not a git repository")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                if gitService.isGitRepo {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(gitService.hasRemote ? .green : .yellow)
                            .frame(width: 8, height: 8)
                        if let remote = gitService.remoteName {
                            Text("Remote: \(remote)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No remote configured (local commits only)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let lastCommit = gitService.lastCommitDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("Last commit: \(lastCommit.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("Sync Now") {
                    Task {
                        await gitService.commitAndPush(at: graphPath)
                    }
                }
                .controlSize(.small)
                .disabled(gitService.isSyncing || !gitService.isGitRepo)

                if gitService.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button("Refresh Status") {
                    gitService.detectGitStatus(at: graphPath)
                }
                .controlSize(.small)
            }

            if let error = gitService.lastError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(3)
                }
            }

            // Log
            if !gitService.syncLog.isEmpty {
                DisclosureGroup("Log") {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(gitService.syncLog.enumerated()), id: \.offset) { idx, entry in
                                    Text(entry)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(entry.contains("ERROR") ? .red : .secondary)
                                        .id(idx)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                        }
                        .frame(height: 100)
                        .background(.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onChange(of: gitService.syncLog.count) {
                            if let last = gitService.syncLog.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
}
