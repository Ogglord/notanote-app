import SwiftUI
import Models
import Services
import MCP

// If launched with --mcp, run as a headless MCP server over stdin/stdout.
// Otherwise, launch the normal menubar GUI app.
if CommandLine.arguments.contains("--mcp") {
    // Determine graph path: check --graph-path <path> flag, then UserDefaults, then default
    var graphPath = "/Users/ogge/repos/notes"
    if let idx = CommandLine.arguments.firstIndex(of: "--graph-path"),
       idx + 1 < CommandLine.arguments.count {
        graphPath = CommandLine.arguments[idx + 1]
    } else if let stored = UserDefaults.standard.string(forKey: "logseq.graphPath"), !stored.isEmpty {
        graphPath = stored
    }

    let digestManager = DigestFileManager(graphPath: graphPath)
    let server = MCPServer(graphPath: graphPath, digestManager: digestManager)
    server.run() // never returns
} else {
    LogSeqTodosApp.main()
}
