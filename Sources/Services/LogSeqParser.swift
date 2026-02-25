import Foundation
import Models

/// Parses LogSeq markdown files and extracts TodoItems
public enum LogSeqParser {

    // MARK: - Public API

    /// Parse a single LogSeq markdown file and return all todo items found
    public static func parseFile(at path: String) -> [TodoItem] {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: "\n")
        let filename = (path as NSString).lastPathComponent
        let journalDate = parseJournalDate(from: filename)

        var items: [TodoItem] = []

        for (index, line) in lines.enumerated() {
            guard let item = parseLine(line, lineNumber: index, filePath: path, journalDate: journalDate, allLines: lines) else {
                continue
            }
            items.append(item)
        }

        return items
    }

    /// Parse a journal date from a filename like `2026_02_23.md`
    public static func parseJournalDate(from filename: String) -> Date? {
        let name = (filename as NSString).deletingPathExtension
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: name)
    }

    /// Update the task marker for a specific line in a file
    public static func updateTaskMarker(in filePath: String, at lineNumber: Int, to newMarker: TaskMarker) throws {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            throw ParserError.fileNotReadable(filePath)
        }

        var lines = content.components(separatedBy: "\n")
        guard lineNumber >= 0, lineNumber < lines.count else {
            throw ParserError.lineOutOfRange(lineNumber)
        }

        let line = lines[lineNumber]
        guard let range = markerRange(in: line) else {
            throw ParserError.noMarkerFound(lineNumber)
        }

        var mutable = line
        mutable.replaceSubrange(range, with: newMarker.rawValue)
        lines[lineNumber] = mutable

        let newContent = lines.joined(separator: "\n")
        try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// Update the text content of a task on a specific line, preserving marker, priority, tags, etc.
    public static func updateTaskContent(in filePath: String, at lineNumber: Int, newContent: String) throws {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            throw ParserError.fileNotReadable(filePath)
        }

        var lines = content.components(separatedBy: "\n")
        guard lineNumber >= 0, lineNumber < lines.count else {
            throw ParserError.lineOutOfRange(lineNumber)
        }

        let line = lines[lineNumber]
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        guard let taskMatch = taskPattern.firstMatch(in: line, range: fullRange) else {
            throw ParserError.noMarkerFound(lineNumber)
        }

        // Build prefix: indentation + "- " + MARKER
        let prefix = nsLine.substring(to: taskMatch.range.upperBound)

        // Preserve priority if present
        let afterMarker = nsLine.substring(from: taskMatch.range.upperBound)
        var priorityStr = ""
        if let priMatch = priorityPattern.firstMatch(in: afterMarker, range: NSRange(location: 0, length: (afterMarker as NSString).length)) {
            priorityStr = " " + (afterMarker as NSString).substring(with: priMatch.range)
        }

        lines[lineNumber] = prefix + priorityStr + " " + newContent
        let newFileContent = lines.joined(separator: "\n")
        try newFileContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// Update the priority of a task on a specific line
    public static func updateTaskPriority(in filePath: String, at lineNumber: Int, to newPriority: TaskPriority) throws {
        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            throw ParserError.fileNotReadable(filePath)
        }

        var lines = content.components(separatedBy: "\n")
        guard lineNumber >= 0, lineNumber < lines.count else {
            throw ParserError.lineOutOfRange(lineNumber)
        }

        var line = lines[lineNumber]
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        guard let taskMatch = taskPattern.firstMatch(in: line, range: fullRange) else {
            throw ParserError.noMarkerFound(lineNumber)
        }

        let afterMarkerStart = taskMatch.range.upperBound
        let afterMarker = nsLine.substring(from: afterMarkerStart)

        // Remove existing priority if present
        let afterNS = afterMarker as NSString
        let afterRange = NSRange(location: 0, length: afterNS.length)
        var cleaned = afterMarker
        if let priMatch = priorityPattern.firstMatch(in: afterMarker, range: afterRange) {
            cleaned = afterNS.replacingCharacters(in: priMatch.range, with: "")
            // Collapse double spaces left behind
            while cleaned.contains("  ") {
                cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
            }
        }

        // Insert new priority right after marker (if not .none)
        let prefix = nsLine.substring(to: afterMarkerStart)
        if newPriority != .none {
            line = prefix + " [#\(newPriority.rawValue)]" + cleaned
        } else {
            line = prefix + cleaned
        }

        lines[lineNumber] = line
        let newFileContent = lines.joined(separator: "\n")
        try newFileContent.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Error type

    public enum ParserError: LocalizedError {
        case fileNotReadable(String)
        case lineOutOfRange(Int)
        case noMarkerFound(Int)

        public var errorDescription: String? {
            switch self {
            case .fileNotReadable(let path): return "Cannot read file at \(path)"
            case .lineOutOfRange(let line): return "Line \(line) is out of range"
            case .noMarkerFound(let line): return "No task marker found on line \(line)"
            }
        }
    }

    // MARK: - Patterns

    private static let markerNames = TaskMarker.allCases.map(\.rawValue)

    // Matches: optional tabs, `- `, then a marker keyword
    private static let taskPattern: NSRegularExpression = {
        let markers = markerNames.joined(separator: "|")
        return try! NSRegularExpression(pattern: #"^(\t*)-\s+("# + markers + #")\b"#)
    }()

    // [#A], [#B], [#C]
    private static let priorityPattern = try! NSRegularExpression(pattern: #"\[#([A-C])\]"#)

    // SCHEDULED: <2024-01-15 ...>  (we only care about the date portion)
    private static let scheduledPattern = try! NSRegularExpression(pattern: #"SCHEDULED:\s*<(\d{4}-\d{2}-\d{2})[^>]*>"#)

    // DEADLINE: <2024-01-15 ...>
    private static let deadlinePattern = try! NSRegularExpression(pattern: #"DEADLINE:\s*<(\d{4}-\d{2}-\d{2})[^>]*>"#)

    // #tag (but not ## markdown headers)
    private static let tagPattern = try! NSRegularExpression(pattern: #"(?<=\s|^)#([\w-]+)"#)

    // [[page reference]]
    private static let pageRefPattern = try! NSRegularExpression(pattern: #"\[\[([^\]]+)\]\]"#)

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Line parsing

    private static func parseLine(_ line: String, lineNumber: Int, filePath: String, journalDate: Date?, allLines: [String]) -> TodoItem? {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        // Must match the task pattern
        guard let taskMatch = taskPattern.firstMatch(in: line, range: fullRange) else {
            return nil
        }

        let tabs = nsLine.substring(with: taskMatch.range(at: 1))
        let indentLevel = tabs.count
        let markerString = nsLine.substring(with: taskMatch.range(at: 2))
        guard let marker = TaskMarker(rawValue: markerString) else { return nil }

        // Everything after the marker
        let afterMarkerStart = taskMatch.range.upperBound
        var rest = nsLine.substring(from: afterMarkerStart)

        // Extract priority
        var priority = TaskPriority.none
        if let priMatch = priorityPattern.firstMatch(in: rest, range: NSRange(location: 0, length: (rest as NSString).length)) {
            let letter = (rest as NSString).substring(with: priMatch.range(at: 1))
            priority = TaskPriority(rawValue: letter) ?? .none
            rest = (rest as NSString).replacingCharacters(in: priMatch.range, with: "")
        }

        // Extract scheduled & deadline from current line
        var scheduledDate = extractDate(from: rest, using: scheduledPattern)
        var deadline = extractDate(from: rest, using: deadlinePattern)

        // Also check the next line if it is more indented (LogSeq sometimes puts dates on a child line)
        if lineNumber + 1 < allLines.count {
            let nextLine = allLines[lineNumber + 1]
            if scheduledDate == nil {
                scheduledDate = extractDate(from: nextLine, using: scheduledPattern)
            }
            if deadline == nil {
                deadline = extractDate(from: nextLine, using: deadlinePattern)
            }
        }

        // Extract tags
        let tags = extractTags(from: line)

        // Extract page references
        let pageRefs = extractPageRefs(from: line)

        // Detect source from tags (#linear, #pylon, or manual)
        let source = TodoSource.detect(from: tags)

        // Extract source URL from markdown links (for Linear/Pylon items)
        let sourceURL = extractSourceURL(from: line, source: source)

        // Build clean content: strip marker, priority, scheduled/deadline, source IDs
        let content = cleanContent(rest, source: source)

        return TodoItem(
            id: "\(filePath):\(lineNumber)",
            marker: marker,
            content: content.trimmingCharacters(in: .whitespaces),
            rawLine: line,
            priority: priority,
            scheduledDate: scheduledDate,
            deadline: deadline,
            tags: tags,
            pageRefs: pageRefs,
            filePath: filePath,
            lineNumber: lineNumber,
            journalDate: journalDate,
            indentLevel: indentLevel,
            source: source,
            sourceURL: sourceURL
        )
    }

    // MARK: - Helpers

    /// Find the range of the marker keyword in a line (for replacement)
    private static func markerRange(in line: String) -> Range<String.Index>? {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        guard let match = taskPattern.firstMatch(in: line, range: fullRange) else { return nil }
        return Range(match.range(at: 2), in: line)
    }

    private static func extractDate(from text: String, using pattern: NSRegularExpression) -> Date? {
        let ns = text as NSString
        guard let match = pattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        let dateStr = ns.substring(with: match.range(at: 1))
        return dateParser.date(from: dateStr)
    }

    private static func extractTags(from text: String) -> [String] {
        let ns = text as NSString
        let matches = tagPattern.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.map { ns.substring(with: $0.range(at: 1)) }
    }

    private static func extractPageRefs(from text: String) -> [String] {
        let ns = text as NSString
        let matches = pageRefPattern.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.map { ns.substring(with: $0.range(at: 1)) }
    }

    // Markdown link pattern: [text](url) — uses .+? to handle nested brackets like [EXT] in titles
    private static let markdownLinkPattern = try! NSRegularExpression(pattern: #"\[(.+?)\]\(([^)]+)\)"#)

    // Source tracking ID pattern: linear:<uuid> or pylon:<uuid>
    private static let sourceIdPattern = try! NSRegularExpression(pattern: #"(?:linear|pylon):[0-9a-fA-F-]+"#)

    // Linear issue identifier pattern: e.g. GNMIS-44, DEL-87
    private static let linearIssueIdPattern = try! NSRegularExpression(pattern: #"\b[A-Z]+-\d+\b"#)

    // Pylon issue number pattern: #NNN (pure digits after #, used for Pylon items)
    private static let pylonNumberPattern = try! NSRegularExpression(pattern: #"(?<=\s)#(\d+)\b"#)

    /// Extract the first URL from a markdown link in the line that points to a known source (Linear or Pylon)
    private static func extractSourceURL(from text: String, source: TodoSource) -> URL? {
        guard source != .manual else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)

        if source == .linear {
            let matches = markdownLinkPattern.matches(in: text, range: range)
            for match in matches {
                let urlString = ns.substring(with: match.range(at: 2))
                if let url = URL(string: urlString), (url.host ?? "").contains("linear.app") {
                    return url
                }
            }
        }

        if source == .pylon {
            // First try to extract URL directly from markdown link
            let matches = markdownLinkPattern.matches(in: text, range: range)
            for match in matches {
                let urlString = ns.substring(with: match.range(at: 2))
                if let url = URL(string: urlString), (url.host ?? "").contains("usepylon.com") {
                    return url
                }
            }
            // Fallback: build Pylon URL from the issue number (e.g. #491 -> ?issueNumber=491)
            if let numMatch = pylonNumberPattern.firstMatch(in: text, range: range) {
                let number = ns.substring(with: numMatch.range(at: 1))
                return URL(string: "https://app.usepylon.com/issues?issueNumber=\(number)")
            }
        }

        return nil
    }

    /// Remove SCHEDULED:/DEADLINE: blocks, markdown links, source tracking IDs, and extra whitespace from content
    private static func cleanContent(_ text: String, source: TodoSource = .manual) -> String {
        var result = text
        // Replace markdown links [text](url) with just the text
        let nsText = result as NSString
        let linkRange = NSRange(location: 0, length: nsText.length)
        result = markdownLinkPattern.stringByReplacingMatches(in: result, range: linkRange, withTemplate: "$1")

        // Remove SCHEDULED: <...>
        if let range = result.range(of: #"SCHEDULED:\s*<[^>]*>"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove DEADLINE: <...>
        if let range = result.range(of: #"DEADLINE:\s*<[^>]*>"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove source tracking IDs (linear:<uuid>, pylon:<uuid>)
        let nsResult = result as NSString
        let idRange = NSRange(location: 0, length: nsResult.length)
        result = sourceIdPattern.stringByReplacingMatches(in: result, range: idRange, withTemplate: "")

        // For digest items, remove the redundant issue identifier suffix (e.g. GNMIS-44)
        // since it's already in the linked title
        if source != .manual {
            let nsClean = result as NSString
            let cleanRange = NSRange(location: 0, length: nsClean.length)
            result = linearIssueIdPattern.stringByReplacingMatches(in: result, range: cleanRange, withTemplate: "")
        }

        // Remove source tags (#linear, #pylon, #high) from display content
        result = result.replacingOccurrences(of: #"\s*#(linear|pylon)\b"#, with: "", options: .regularExpression)

        // Collapse multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
