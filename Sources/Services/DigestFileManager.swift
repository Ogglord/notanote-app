import Foundation

/// Manages reading and writing of source digest files (e.g. pages/linear-digest.md, pages/pylon-digest.md)
public struct DigestFileManager {
    public let graphPath: String

    public init(graphPath: String) {
        self.graphPath = graphPath
    }

    /// Resolve the file path for a source digest page (e.g. pages/linear-digest.md)
    public func digestFilePath(for source: String) -> String {
        let pagesDir = (graphPath as NSString).appendingPathComponent("pages")
        return (pagesDir as NSString).appendingPathComponent("\(source)-digest.md")
    }

    /// Extract all source tracking UUIDs from an existing digest file.
    /// Looks for patterns like `linear:UUID` or `pylon:UUID` and returns the set of UUIDs.
    public func existingSourceIds(in filePath: String, for source: String) -> Set<String> {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        var ids = Set<String>()
        let pattern = "\(source):([0-9a-fA-F][0-9a-fA-F-]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, range: range) {
            if let idRange = Range(match.range(at: 1), in: content) {
                ids.insert(String(content[idRange]))
            }
        }
        return ids
    }

    /// Build a markdown todo line for a source item
    public func buildSourceLine(
        text: String,
        source: String,
        sourceId: String?,
        url: String?,
        identifier: String?,
        priority: String?,
        status: String?
    ) -> String {
        let marker = status ?? "TODO"
        var line = "- \(marker) "

        if let p = priority, ["A", "B", "C"].contains(p) {
            line += "[#\(p)] "
        }

        // If we have a URL and identifier, make the text a markdown link
        if let url = url, !url.isEmpty, let id = identifier, !id.isEmpty {
            line += "[\(id) \(text)](\(url))"
        } else if let url = url, !url.isEmpty {
            line += "[\(text)](\(url))"
        } else {
            line += text
        }

        // Append source tag
        line += " #\(source)"

        // Append tracking ID for future sync lookups
        if let sid = sourceId, !sid.isEmpty {
            line += " \(source):\(sid)"
        }

        return line
    }

    /// Append a single source todo item to the digest file
    public func appendItem(
        source: String,
        text: String,
        sourceId: String?,
        url: String?,
        identifier: String?,
        priority: String?
    ) -> String {
        let line = buildSourceLine(
            text: text, source: source, sourceId: sourceId,
            url: url, identifier: identifier, priority: priority, status: nil
        )

        let filePath = digestFilePath(for: source)
        let fm = FileManager.default
        let pagesDir = (graphPath as NSString).appendingPathComponent("pages")

        // Ensure pages directory exists
        if !fm.fileExists(atPath: pagesDir) {
            try? fm.createDirectory(atPath: pagesDir, withIntermediateDirectories: true)
        }

        if fm.fileExists(atPath: filePath),
           let data = fm.contents(atPath: filePath),
           var content = String(data: data, encoding: .utf8) {
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = line + "\n"
            } else {
                content += "\n" + line
            }
            try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } else {
            try? (line + "\n").write(toFile: filePath, atomically: true, encoding: .utf8)
        }

        return line
    }

    /// Resolve the file path for the notifications digest page (pages/notifications.md)
    public func notificationsFilePath() -> String {
        let pagesDir = (graphPath as NSString).appendingPathComponent("pages")
        return (pagesDir as NSString).appendingPathComponent("notifications.md")
    }

    /// Replace the entire notifications digest file with the provided lines
    public func writeNotifications(lines: [String]) {
        let filePath = notificationsFilePath()
        let fm = FileManager.default
        let pagesDir = (graphPath as NSString).appendingPathComponent("pages")

        if !fm.fileExists(atPath: pagesDir) {
            try? fm.createDirectory(atPath: pagesDir, withIntermediateDirectories: true)
        }

        let content = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// Replace the entire contents of a source digest file with the provided lines
    public func syncItems(source: String, lines: [String]) {
        let filePath = digestFilePath(for: source)
        let fm = FileManager.default
        let pagesDir = (graphPath as NSString).appendingPathComponent("pages")

        if !fm.fileExists(atPath: pagesDir) {
            try? fm.createDirectory(atPath: pagesDir, withIntermediateDirectories: true)
        }

        let content = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
}
