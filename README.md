# LogSeq Todos

A lightweight macOS menu bar app that turns LogSeq-flavored markdown into a fast, always-accessible todo list. Works standalone or alongside an existing LogSeq graph -- your todos stay as plain `.md` files you own forever.

Ships with a built-in **MCP server** so AI assistants can read, create, and manage your todos directly.

## Why

- **Plain text, zero lock-in** -- todos live as markdown files in `journals/` and `pages/`, the same format LogSeq uses
- **Menu bar native** -- one click to see what's on your plate, keyboard-driven, no window management
- **AI-ready** -- built-in MCP server lets Claude, Cursor, and other agents work with your task list
- **Syncs with your tools** -- pulls issues from Linear and Pylon into digest pages automatically
- **Git sync** -- optional auto commit + push to keep everything backed up

## Install

```bash
swift build
```

The binary lands at `.build/debug/LogSeqTodos`. Run it for the GUI, or with `--mcp` for headless MCP mode.

Requires macOS 14+ and Swift 5.9+.

## How it works

```
journals/2024_01_15.md          pages/linear-digest.md
         |                               |
         +--------> LogSeqParser <-------+
                        |
                   [ TodoItem ]
                        |
                    TodoStore (watches for file changes)
                        |
                  Menu bar popover
```

Todos are standard LogSeq markdown:

```markdown
- TODO Buy groceries
- TODO [#A] Fix critical bug #work
- DOING [#B] Review the auth PR
- DONE Ship v2.0
- WAITING Deploy to staging DEADLINE: <2024-03-20>
```

Markers: `TODO` `DOING` `DONE` `NOW` `LATER` `WAITING` `CANCELLED`
Priority: `[#A]` high, `[#B]` medium, `[#C]` low

## Storage

Pick one:

- **LogSeq mode** -- point it at your existing graph
- **Standalone mode** -- uses `~/.logseq-todos/` with the same directory structure
- **Git sync** -- auto commit + push on a configurable interval

## MCP server

Add to your MCP client config:

```json
{
  "mcpServers": {
    "logseq-todos": {
      "command": "/path/to/LogSeqTodos",
      "args": ["--mcp"]
    }
  }
}
```

JSON-RPC 2.0 over stdin/stdout. Available tools:

| Tool | What it does |
|------|-------------|
| `list_todos` | Query with filters, search, tags, source |
| `add_todo` | Add to today's journal |
| `update_todo` | Change status (TODO/DOING/DONE/...) |
| `add_source_todo` | Add to Linear/Pylon digest (deduplicates) |
| `remove_todo` | Delete a line |
| `sync_source` | Bulk-replace a digest file |

Override the graph path with `--graph-path /your/path`.

## Architecture

Five SPM modules with a clean dependency graph:

```
Models          -- pure data types, Foundation-only
  ^       ^
  |       |
Services  Networking  -- file I/O, parsing | HTTP, Keychain
  ^  ^      ^    ^
  |  +--+---+    |
  |     |        |
  |    MCP       |  -- JSON-RPC server
  +----+----+----+
       |
  LogSeqTodos       -- SwiftUI menu bar app
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full breakdown.

## License

MIT
