import Foundation
import Observation

@Observable
public final class GitSyncService {
    public private(set) var isGitRepo = false
    public private(set) var hasRemote = false
    public private(set) var remoteName: String?
    public private(set) var lastCommitDate: Date?
    public private(set) var lastError: String?
    public private(set) var isSyncing = false

    public var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "git.enabled") }
    }

    public var syncIntervalMinutes: Double {
        didSet { UserDefaults.standard.set(syncIntervalMinutes, forKey: "git.syncInterval") }
    }

    public var commitMessageTemplate: String {
        didSet { UserDefaults.standard.set(commitMessageTemplate, forKey: "git.commitTemplate") }
    }

    private var syncTask: Task<Void, Never>?

    public init() {
        self.enabled = UserDefaults.standard.bool(forKey: "git.enabled")
        let interval = UserDefaults.standard.double(forKey: "git.syncInterval")
        self.syncIntervalMinutes = interval > 0 ? interval : 5
        self.commitMessageTemplate = UserDefaults.standard.string(forKey: "git.commitTemplate")
            ?? "Auto-sync: {date}"
    }

    /// Detect if the given path is inside a git repo with a remote
    public func detectGitStatus(at path: String) {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let result = try self.runGit(at: path, args: ["rev-parse", "--is-inside-work-tree"])
                let isRepo = result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
                await MainActor.run { self.isGitRepo = isRepo }

                if isRepo {
                    let remoteOutput = try self.runGit(at: path, args: ["remote"])
                    let remotes = remoteOutput.split(separator: "\n").map(String.init)
                    let foundRemote = !remotes.isEmpty
                    let name = remotes.first
                    await MainActor.run {
                        self.hasRemote = foundRemote
                        self.remoteName = name
                    }
                } else {
                    await MainActor.run {
                        self.hasRemote = false
                        self.remoteName = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.isGitRepo = false
                    self.hasRemote = false
                    self.remoteName = nil
                }
            }
        }
    }

    /// Commit all changes and push if remote exists
    public func commitAndPush(at path: String) async {
        await MainActor.run {
            isSyncing = true
            lastError = nil
        }
        defer {
            Task { @MainActor in
                isSyncing = false
            }
        }

        let message = commitMessageTemplate.replacingOccurrences(
            of: "{date}",
            with: ISO8601DateFormatter().string(from: Date())
        )

        do {
            // Stage all changes
            _ = try runGit(at: path, args: ["add", "-A"])

            // Check if there are staged changes
            let diffStatus = runGitExitCode(at: path, args: ["diff", "--cached", "--quiet"])
            if diffStatus == 0 {
                // No changes to commit
                return
            }

            // Commit
            _ = try runGit(at: path, args: ["commit", "-m", message])

            // Push if remote exists
            let pushRemote = await MainActor.run { self.hasRemote }
            if pushRemote {
                _ = try runGit(at: path, args: ["push"])
            }

            await MainActor.run {
                self.lastCommitDate = Date()
            }
        } catch let error as GitError {
            await MainActor.run {
                self.lastError = error.errorDescription
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
        }
    }

    public func startPeriodicSync(at path: String) {
        stopPeriodicSync()
        guard enabled else { return }

        syncTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = await MainActor.run { self.syncIntervalMinutes }
                try? await Task.sleep(for: .seconds(interval * 60))
                if Task.isCancelled { return }
                let isEnabled = await MainActor.run { self.enabled }
                guard isEnabled else { return }
                await self.commitAndPush(at: path)
            }
        }
    }

    public func stopPeriodicSync() {
        syncTask?.cancel()
        syncTask = nil
    }

    // MARK: - Shell helpers

    private func runGit(at path: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw GitError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Run git and return only the exit code (no throw on non-zero)
    private func runGitExitCode(at path: String, args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path] + args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}

public enum GitError: LocalizedError {
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let output):
            return "Git command failed: \(output)"
        }
    }
}
