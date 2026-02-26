import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.notanote", category: "GitSyncService")

@Observable
public final class GitSyncService {
    public private(set) var isGitRepo = false
    public private(set) var hasRemote = false
    public private(set) var remoteName: String?
    public private(set) var lastCommitDate: Date?
    public private(set) var lastError: String?
    public private(set) var isSyncing = false
    public private(set) var syncLog: [String] = []
    public private(set) var hasConflict = false
    private var conflictPath: String?

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

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private func log(_ message: String) {
        let entry = "[\(Self.timestampFormatter.string(from: Date()))] Git: \(message)"
        logger.info("\(entry)")
        syncLog.append(entry)
        if syncLog.count > 50 { syncLog.removeFirst(syncLog.count - 50) }
    }

    public init() {
        self.enabled = UserDefaults.standard.bool(forKey: "git.enabled")
        let interval = UserDefaults.standard.double(forKey: "git.syncInterval")
        self.syncIntervalMinutes = interval > 0 ? interval : 5
        self.commitMessageTemplate = UserDefaults.standard.string(forKey: "git.commitTemplate")
            ?? "Auto-sync: {date}"
    }

    /// Detect if the given path is inside a git repo with a remote.
    /// This runs git commands synchronously (they're fast) so state is set immediately.
    public func detectGitStatus(at path: String) {
        do {
            let result = try runGit(at: path, args: ["rev-parse", "--is-inside-work-tree"])
            let isRepo = result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            isGitRepo = isRepo
            log("Detected git repo: \(isRepo)")

            if isRepo {
                let remoteOutput = try runGit(at: path, args: ["remote"])
                let remotes = remoteOutput.split(separator: "\n").map(String.init)
                hasRemote = !remotes.isEmpty
                remoteName = remotes.first
                if hasRemote {
                    log("Remote: \(remoteName ?? "unknown")")
                } else {
                    log("No remote configured")
                }
            } else {
                hasRemote = false
                remoteName = nil
            }
        } catch {
            isGitRepo = false
            hasRemote = false
            remoteName = nil
            log("Git detection failed: \(error.localizedDescription)")
        }
    }

    /// Commit all changes and push if remote exists
    public func commitAndPush(at path: String) async {
        await MainActor.run {
            isSyncing = true
            lastError = nil
            log("Starting commit & push at \(path)")
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
                await MainActor.run { log("No changes to commit") }
                return
            }

            // Commit
            _ = try runGit(at: path, args: ["commit", "-m", message])
            await MainActor.run { log("Committed changes") }

            // Push if remote exists
            let pushRemote = await MainActor.run { self.hasRemote }
            if pushRemote {
                // Pull remote changes first to avoid non-fast-forward errors
                let pullExitCode = runGitExitCode(at: path, args: ["pull", "--rebase"])
                if pullExitCode != 0 {
                    // Rebase failed – likely a conflict
                    _ = runGitExitCode(at: path, args: ["rebase", "--abort"])
                    await MainActor.run {
                        self.hasConflict = true
                        self.conflictPath = path
                        self.lastError = "Sync conflict: local and remote have diverged. Choose to keep local notes or cloud notes."
                        log("Conflict detected – rebase aborted. User action required.")
                    }
                    return
                }
                await MainActor.run { log("Pulled remote changes") }

                _ = try runGit(at: path, args: ["push"])
                await MainActor.run { log("Pushed to remote") }
            }

            await MainActor.run {
                self.lastCommitDate = Date()
                log("Sync complete")
            }
        } catch let error as GitError {
            await MainActor.run {
                self.lastError = error.errorDescription
                log("ERROR: \(error.errorDescription ?? "unknown")")
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                log("ERROR: \(error.localizedDescription)")
            }
        }
    }

    public func startPeriodicSync(at path: String) {
        stopPeriodicSync()
        guard enabled else { return }

        syncTask = Task.detached { [weak self] in
            // Run an initial sync immediately
            if let self { await self.commitAndPush(at: path) }
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

    // MARK: - Conflict resolution

    /// Keep local notes and force-push to overwrite the remote.
    public func resolveKeepLocal() async {
        guard let path = conflictPath else { return }
        await MainActor.run {
            isSyncing = true
            log("Resolving conflict: keeping LOCAL notes")
        }
        defer { Task { @MainActor in isSyncing = false } }

        do {
            _ = try runGit(at: path, args: ["push", "--force-with-lease"])
            await MainActor.run {
                hasConflict = false
                conflictPath = nil
                lastError = nil
                lastCommitDate = Date()
                log("Force-pushed local notes to remote")
            }
        } catch let error as GitError {
            await MainActor.run {
                lastError = error.errorDescription
                log("ERROR: \(error.errorDescription ?? "unknown")")
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                log("ERROR: \(error.localizedDescription)")
            }
        }
    }

    /// Keep cloud notes and reset local to match the remote.
    public func resolveKeepCloud() async {
        guard let path = conflictPath else { return }
        await MainActor.run {
            isSyncing = true
            log("Resolving conflict: keeping CLOUD notes")
        }
        defer { Task { @MainActor in isSyncing = false } }

        do {
            // Fetch latest from remote
            _ = try runGit(at: path, args: ["fetch"])
            // Find upstream branch
            let branch = try runGit(at: path, args: ["rev-parse", "--abbrev-ref", "HEAD"])
            let remote = remoteName ?? "origin"
            _ = try runGit(at: path, args: ["reset", "--hard", "\(remote)/\(branch)"])
            await MainActor.run {
                hasConflict = false
                conflictPath = nil
                lastError = nil
                lastCommitDate = Date()
                log("Reset local to match remote")
            }
        } catch let error as GitError {
            await MainActor.run {
                lastError = error.errorDescription
                log("ERROR: \(error.errorDescription ?? "unknown")")
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                log("ERROR: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Shell helpers

    private func runGit(at path: String, args: [String]) throws -> String {
        let cmd = "git -C \(path) \(args.joined(separator: " "))"
        log("$ \(cmd)")
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
            log("  ✗ exit \(process.terminationStatus): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            throw GitError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            log("  ✓ \(trimmed)")
        }
        return trimmed
    }

    /// Run git and return only the exit code (no throw on non-zero)
    private func runGitExitCode(at path: String, args: [String]) -> Int32 {
        let cmd = "git -C \(path) \(args.joined(separator: " "))"
        log("$ \(cmd)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path] + args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            log("  → exit \(process.terminationStatus)")
            return process.terminationStatus
        } catch {
            log("  ✗ failed to run: \(error.localizedDescription)")
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
