import Foundation
import Models
import Services

/// A minimal MCP (Model Context Protocol) server that communicates over stdin/stdout
/// using JSON-RPC 2.0. Exposes LogSeq todo items as tools.
public final class MCPServer {
    private let graphPath: String
    private let digestManager: DigestFileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(graphPath: String, digestManager: DigestFileManager) {
        self.graphPath = graphPath
        self.digestManager = digestManager
        encoder.outputFormatting = [] // compact JSON, no pretty printing
    }

    /// Run the MCP server loop -- blocks forever reading stdin
    public func run() -> Never {
        // Read line-delimited JSON-RPC messages from stdin
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }
            guard let data = line.data(using: .utf8) else { continue }

            do {
                let request = try decoder.decode(JSONRPCRequest.self, from: data)
                if let response = handleRequest(request) {
                    send(response)
                }
            } catch {
                let errResponse = JSONRPCResponse(
                    jsonrpc: "2.0",
                    id: nil,
                    result: nil,
                    error: .init(code: -32700, message: "Parse error: \(error.localizedDescription)")
                )
                send(errResponse)
            }
        }
        exit(0)
    }

    // MARK: - Request routing

    private func handleRequest(_ request: JSONRPCRequest) -> JSONRPCResponse? {
        switch request.method {
        case "initialize":
            return handleInitialize(request)
        case "notifications/initialized":
            // Notification -- no response per JSON-RPC 2.0
            return nil
        case "tools/list":
            return handleToolsList(request)
        case "tools/call":
            return handleToolsCall(request)
        default:
            return JSONRPCResponse(
                jsonrpc: "2.0",
                id: request.id,
                result: nil,
                error: .init(code: -32601, message: "Method not found: \(request.method)")
            )
        }
    }

    // MARK: - Initialize

    private func handleInitialize(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let result: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": [:] as [String: Any]
            ] as [String: Any],
            "serverInfo": [
                "name": "logseq-todos",
                "version": "1.0.0"
            ] as [String: Any]
        ]
        return makeResult(id: request.id, result: AnyCodable(result))
    }

    // MARK: - Tools List

    private func handleToolsList(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let tools: [[String: Any]] = [
            [
                "name": "list_todos",
                "description": "List todo items from the LogSeq graph. Returns todos with their status, content, tags, page references, priority, and source file info.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "filter": [
                            "type": "string",
                            "description": "Filter mode: 'all', 'active' (default), 'today', 'overdue', 'done'",
                            "enum": ["all", "active", "today", "overdue", "done"]
                        ] as [String: Any],
                        "search": [
                            "type": "string",
                            "description": "Optional text search across content, tags, and page references"
                        ] as [String: Any],
                        "tag": [
                            "type": "string",
                            "description": "Optional: filter by specific tag (without #)"
                        ] as [String: Any],
                        "limit": [
                            "type": "number",
                            "description": "Max number of items to return (default: 50)"
                        ] as [String: Any],
                        "source": [
                            "type": "string",
                            "description": "Optional: filter by source ('manual', 'linear', 'pylon')",
                            "enum": ["manual", "linear", "pylon"]
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": [] as [String]
                ] as [String: Any]
            ] as [String: Any],
            [
                "name": "add_todo",
                "description": "Add a new TODO item to today's LogSeq journal file. The item is prepended to the journal as '- TODO <text>'.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "text": [
                            "type": "string",
                            "description": "The todo item text"
                        ] as [String: Any],
                        "priority": [
                            "type": "string",
                            "description": "Optional priority: 'A' (high), 'B' (medium), 'C' (low)",
                            "enum": ["A", "B", "C"]
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": ["text"]
                ] as [String: Any]
            ] as [String: Any],
            [
                "name": "update_todo",
                "description": "Update the status of an existing todo item. Changes the marker (TODO/DONE/NOW/LATER/DOING/WAITING/CANCELLED) in the source file.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "file_path": [
                            "type": "string",
                            "description": "The full path to the markdown file containing the todo"
                        ] as [String: Any],
                        "line_number": [
                            "type": "number",
                            "description": "The 0-based line number of the todo in the file"
                        ] as [String: Any],
                        "new_status": [
                            "type": "string",
                            "description": "The new status marker",
                            "enum": ["TODO", "DOING", "DONE", "NOW", "LATER", "WAITING", "CANCELLED"]
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": ["file_path", "line_number", "new_status"]
                ] as [String: Any]
            ] as [String: Any],
            [
                "name": "add_source_todo",
                "description": "Add a TODO item to a source-specific digest page (e.g. pages/linear-digest.md or pages/pylon-digest.md). The item is tagged with the source and includes an optional tracking ID and URL.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "source": [
                            "type": "string",
                            "description": "The source type: 'linear' or 'pylon'",
                            "enum": ["linear", "pylon"]
                        ] as [String: Any],
                        "text": [
                            "type": "string",
                            "description": "The todo item text (e.g. issue title)"
                        ] as [String: Any],
                        "source_id": [
                            "type": "string",
                            "description": "Optional tracking ID (e.g. Linear issue UUID or Pylon issue UUID)"
                        ] as [String: Any],
                        "url": [
                            "type": "string",
                            "description": "Optional URL to the item in its source app"
                        ] as [String: Any],
                        "identifier": [
                            "type": "string",
                            "description": "Optional short identifier (e.g. 'EXT-42' for Linear or '#491' for Pylon)"
                        ] as [String: Any],
                        "priority": [
                            "type": "string",
                            "description": "Optional priority: 'A' (high), 'B' (medium), 'C' (low)",
                            "enum": ["A", "B", "C"]
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": ["source", "text"]
                ] as [String: Any]
            ] as [String: Any],
            [
                "name": "remove_todo",
                "description": "Remove a todo line from a file entirely. Use this to clean up stale items from digest files (e.g. when an issue was closed externally).",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "file_path": [
                            "type": "string",
                            "description": "The full path to the markdown file containing the todo"
                        ] as [String: Any],
                        "line_number": [
                            "type": "number",
                            "description": "The 0-based line number of the todo to remove"
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": ["file_path", "line_number"]
                ] as [String: Any]
            ] as [String: Any],
            [
                "name": "sync_source",
                "description": "Replace the entire contents of a source digest file with the provided todo items. Useful for bulk-syncing from Linear or Pylon -- wipes the file and writes all items fresh. The file is at pages/<source>-digest.md.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "source": [
                            "type": "string",
                            "description": "The source type: 'linear' or 'pylon'",
                            "enum": ["linear", "pylon"]
                        ] as [String: Any],
                        "items": [
                            "type": "array",
                            "description": "Array of todo items to write",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "text": [
                                        "type": "string",
                                        "description": "The todo item text"
                                    ] as [String: Any],
                                    "source_id": [
                                        "type": "string",
                                        "description": "Optional tracking ID"
                                    ] as [String: Any],
                                    "url": [
                                        "type": "string",
                                        "description": "Optional URL to the item"
                                    ] as [String: Any],
                                    "identifier": [
                                        "type": "string",
                                        "description": "Optional short identifier (e.g. 'EXT-42' or '#491')"
                                    ] as [String: Any],
                                    "status": [
                                        "type": "string",
                                        "description": "Optional status marker (default: 'TODO')",
                                        "enum": ["TODO", "DOING", "DONE", "NOW", "LATER", "WAITING", "CANCELLED"]
                                    ] as [String: Any],
                                    "priority": [
                                        "type": "string",
                                        "description": "Optional priority: 'A', 'B', 'C'",
                                        "enum": ["A", "B", "C"]
                                    ] as [String: Any]
                                ] as [String: Any],
                                "required": ["text"]
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any],
                    "required": ["source", "items"]
                ] as [String: Any]
            ] as [String: Any]
        ]
        return makeResult(id: request.id, result: AnyCodable(["tools": tools]))
    }

    // MARK: - Tools Call

    private func handleToolsCall(_ request: JSONRPCRequest) -> JSONRPCResponse {
        guard let params = request.params,
              let name = params["name"] as? String else {
            return makeError(id: request.id, code: -32602, message: "Missing tool name")
        }
        let arguments = params["arguments"] as? [String: Any] ?? [:]

        switch name {
        case "list_todos":
            return callListTodos(id: request.id, args: arguments)
        case "add_todo":
            return callAddTodo(id: request.id, args: arguments)
        case "update_todo":
            return callUpdateTodo(id: request.id, args: arguments)
        case "add_source_todo":
            return callAddSourceTodo(id: request.id, args: arguments)
        case "remove_todo":
            return callRemoveTodo(id: request.id, args: arguments)
        case "sync_source":
            return callSyncSource(id: request.id, args: arguments)
        default:
            return makeError(id: request.id, code: -32602, message: "Unknown tool: \(name)")
        }
    }

    // MARK: - Tool implementations

    private func callListTodos(id: RequestID?, args: [String: Any]) -> JSONRPCResponse {
        let filter = args["filter"] as? String ?? "active"
        let search = args["search"] as? String
        let tag = args["tag"] as? String
        let limit = args["limit"] as? Int ?? 50

        var items = loadAllItems()

        // Filter
        switch filter {
        case "active":
            items = items.filter { $0.marker.isActive }
        case "today":
            items = items.filter { item in
                let cal = Calendar.current
                if let j = item.journalDate, cal.isDateInToday(j) { return true }
                if let s = item.scheduledDate, cal.isDateInToday(s) { return true }
                return false
            }
        case "overdue":
            items = items.filter { $0.isOverdue }
        case "done":
            items = items.filter { $0.marker.isCompleted }
        default: // "all"
            break
        }

        // Search
        if let search = search, !search.isEmpty {
            let q = search.lowercased()
            items = items.filter {
                $0.content.lowercased().contains(q) ||
                $0.tags.contains(where: { $0.lowercased().contains(q) }) ||
                $0.pageRefs.contains(where: { $0.lowercased().contains(q) })
            }
        }

        // Tag filter
        if let tag = tag, !tag.isEmpty {
            let t = tag.lowercased()
            items = items.filter { $0.tags.contains(where: { $0.lowercased() == t }) }
        }

        // Source filter
        if let sourceStr = args["source"] as? String,
           let source = TodoSource(rawValue: sourceStr) {
            items = items.filter { $0.source == source }
        }

        // Limit
        if items.count > limit {
            items = Array(items.prefix(limit))
        }

        let output = items.map { formatTodoItem($0) }
        let text = output.isEmpty
            ? "No todos found matching filter '\(filter)'"
            : "\(output.count) todo(s) found:\n\n" + output.joined(separator: "\n---\n")

        return makeToolResult(id: id, text: text)
    }

    private func callAddTodo(id: RequestID?, args: [String: Any]) -> JSONRPCResponse {
        guard let text = args["text"] as? String, !text.isEmpty else {
            return makeToolResult(id: id, text: "Error: 'text' parameter is required", isError: true)
        }

        let priority = args["priority"] as? String
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayFilename = formatter.string(from: Date()) + ".md"

        let journalsDir = (graphPath as NSString).appendingPathComponent("journals")
        let filePath = (journalsDir as NSString).appendingPathComponent(todayFilename)

        var line = "- TODO "
        if let p = priority, ["A", "B", "C"].contains(p) {
            line += "[#\(p)] "
        }
        line += text

        let fm = FileManager.default
        if !fm.fileExists(atPath: journalsDir) {
            try? fm.createDirectory(atPath: journalsDir, withIntermediateDirectories: true)
        }

        if fm.fileExists(atPath: filePath),
           let data = fm.contents(atPath: filePath),
           var content = String(data: data, encoding: .utf8) {
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                content = line + "\n"
            } else {
                content = line + "\n" + content
            }
            try? content.write(toFile: filePath, atomically: true, encoding: .utf8)
        } else {
            try? (line + "\n").write(toFile: filePath, atomically: true, encoding: .utf8)
        }

        return makeToolResult(id: id, text: "Added to \(todayFilename):\n\(line)")
    }

    private func callUpdateTodo(id: RequestID?, args: [String: Any]) -> JSONRPCResponse {
        guard let filePath = args["file_path"] as? String else {
            return makeToolResult(id: id, text: "Error: 'file_path' is required", isError: true)
        }
        guard let lineNumber = args["line_number"] as? Int else {
            return makeToolResult(id: id, text: "Error: 'line_number' is required", isError: true)
        }
        guard let newStatus = args["new_status"] as? String,
              let marker = TaskMarker(rawValue: newStatus) else {
            return makeToolResult(id: id, text: "Error: 'new_status' must be one of: TODO, DOING, DONE, NOW, LATER, WAITING, CANCELLED", isError: true)
        }

        do {
            try LogSeqParser.updateTaskMarker(in: filePath, at: lineNumber, to: marker)
            return makeToolResult(id: id, text: "Updated line \(lineNumber) in \((filePath as NSString).lastPathComponent) to \(newStatus)")
        } catch {
            return makeToolResult(id: id, text: "Error: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Source digest tools

    private func callAddSourceTodo(id: RequestID?, args: [String: Any]) -> JSONRPCResponse {
        guard let source = args["source"] as? String, ["linear", "pylon"].contains(source) else {
            return makeToolResult(id: id, text: "Error: 'source' must be 'linear' or 'pylon'", isError: true)
        }
        guard let text = args["text"] as? String, !text.isEmpty else {
            return makeToolResult(id: id, text: "Error: 'text' parameter is required", isError: true)
        }

        let sourceId = args["source_id"] as? String
        let url = args["url"] as? String
        let identifier = args["identifier"] as? String
        let priority = args["priority"] as? String

        // Reject duplicates by source_id (UUID)
        if let sid = sourceId, !sid.isEmpty {
            let filePath = digestManager.digestFilePath(for: source)
            let existing = digestManager.existingSourceIds(in: filePath, for: source)
            if existing.contains(sid) {
                return makeToolResult(id: id, text: "Skipped: item with \(source) ID \(sid) already exists in \((filePath as NSString).lastPathComponent)")
            }
        }

        let line = digestManager.appendItem(
            source: source, text: text, sourceId: sourceId,
            url: url, identifier: identifier, priority: priority
        )

        let filePath = digestManager.digestFilePath(for: source)
        let filename = (filePath as NSString).lastPathComponent
        return makeToolResult(id: id, text: "Added to \(filename):\n\(line)")
    }

    private func callRemoveTodo(id: RequestID?, args: [String: Any]) -> JSONRPCResponse {
        guard let filePath = args["file_path"] as? String else {
            return makeToolResult(id: id, text: "Error: 'file_path' is required", isError: true)
        }
        guard let lineNumber = args["line_number"] as? Int else {
            return makeToolResult(id: id, text: "Error: 'line_number' is required", isError: true)
        }

        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            return makeToolResult(id: id, text: "Error: Cannot read file at \(filePath)", isError: true)
        }

        var lines = content.components(separatedBy: "\n")
        guard lineNumber >= 0, lineNumber < lines.count else {
            return makeToolResult(id: id, text: "Error: Line \(lineNumber) is out of range (file has \(lines.count) lines)", isError: true)
        }

        let removed = lines[lineNumber]
        lines.remove(at: lineNumber)

        // Clean up: remove trailing empty lines but keep at least one newline at end
        let newContent = lines.joined(separator: "\n")
        try? newContent.write(toFile: filePath, atomically: true, encoding: .utf8)

        let filename = (filePath as NSString).lastPathComponent
        return makeToolResult(id: id, text: "Removed line \(lineNumber) from \(filename):\n\(removed)")
    }

    private func callSyncSource(id: RequestID?, args: [String: Any]) -> JSONRPCResponse {
        guard let source = args["source"] as? String, ["linear", "pylon"].contains(source) else {
            return makeToolResult(id: id, text: "Error: 'source' must be 'linear' or 'pylon'", isError: true)
        }
        guard let items = args["items"] as? [[String: Any]] else {
            return makeToolResult(id: id, text: "Error: 'items' must be an array of objects", isError: true)
        }

        // Build all lines, deduplicating by source_id (UUID)
        var lines: [String] = []
        var seenIds = Set<String>()
        var skipped = 0
        for item in items {
            guard let text = item["text"] as? String, !text.isEmpty else { continue }
            if let sid = item["source_id"] as? String, !sid.isEmpty {
                if seenIds.contains(sid) {
                    skipped += 1
                    continue
                }
                seenIds.insert(sid)
            }
            let line = digestManager.buildSourceLine(
                text: text,
                source: source,
                sourceId: item["source_id"] as? String,
                url: item["url"] as? String,
                identifier: item["identifier"] as? String,
                priority: item["priority"] as? String,
                status: item["status"] as? String
            )
            lines.append(line)
        }

        digestManager.syncItems(source: source, lines: lines)

        let filePath = digestManager.digestFilePath(for: source)
        let filename = (filePath as NSString).lastPathComponent
        var msg = "Synced \(lines.count) item(s) to \(filename)"
        if skipped > 0 {
            msg += " (\(skipped) duplicate(s) skipped)"
        }
        return makeToolResult(id: id, text: msg)
    }

    // MARK: - Helpers

    private func loadAllItems() -> [TodoItem] {
        let fm = FileManager.default
        var allItems: [TodoItem] = []
        for dir in ["journals", "pages"] {
            let dirPath = (graphPath as NSString).appendingPathComponent(dir)
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".md") {
                let fullPath = (dirPath as NSString).appendingPathComponent(file)
                allItems.append(contentsOf: LogSeqParser.parseFile(at: fullPath))
            }
        }
        // Sort: active first, then by priority, then by date (newest first)
        return allItems.sorted { a, b in
            if a.marker.isActive != b.marker.isActive { return a.marker.isActive }
            if a.priority != b.priority { return a.priority < b.priority }
            return (a.journalDate ?? .distantPast) > (b.journalDate ?? .distantPast)
        }
    }

    private func formatTodoItem(_ item: TodoItem) -> String {
        var parts: [String] = []
        parts.append("[\(item.marker.rawValue)] \(item.content)")
        if item.priority != .none { parts.append("  Priority: \(item.priority.rawValue)") }
        if !item.tags.isEmpty { parts.append("  Tags: \(item.tags.map { "#\($0)" }.joined(separator: " "))") }
        if !item.pageRefs.isEmpty { parts.append("  Pages: \(item.pageRefs.map { "[[\($0)]]" }.joined(separator: " "))") }
        if let d = item.scheduledDate { parts.append("  Scheduled: \(iso(d))") }
        if let d = item.deadline { parts.append("  Deadline: \(iso(d))\(item.isOverdue ? " OVERDUE" : "")") }
        parts.append("  Origin: \(item.source.displayName)")
        parts.append("  Source: \((item.filePath as NSString).lastPathComponent):\(item.lineNumber)")
        parts.append("  File: \(item.filePath)")
        if let j = item.journalDate { parts.append("  Journal: \(iso(j))") }
        return parts.joined(separator: "\n")
    }

    private func iso(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    // MARK: - JSON-RPC response helpers

    private func makeResult(id: RequestID?, result: AnyCodable) -> JSONRPCResponse {
        JSONRPCResponse(jsonrpc: "2.0", id: id, result: result, error: nil)
    }

    private func makeError(id: RequestID?, code: Int, message: String) -> JSONRPCResponse {
        JSONRPCResponse(jsonrpc: "2.0", id: id, result: nil, error: .init(code: code, message: message))
    }

    private func makeToolResult(id: RequestID?, text: String, isError: Bool = false) -> JSONRPCResponse {
        let content: [[String: Any]] = [["type": "text", "text": text]]
        var result: [String: Any] = ["content": content]
        if isError { result["isError"] = true }
        return makeResult(id: id, result: AnyCodable(result))
    }

    private func send(_ response: JSONRPCResponse) {
        guard let data = try? encoder.encode(response) else { return }
        guard let jsonString = String(data: data, encoding: .utf8) else { return }
        print(jsonString)
        fflush(stdout)
    }
}
