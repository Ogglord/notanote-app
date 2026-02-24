# LogSeq Todos - Architecture

## Module Structure

```
Sources/
  Models/          (library, Foundation-only)
    |-- TodoItem, TodoSource, TaskMarker, TaskPriority, GroupMode
    |
  Services/        (library, depends: Models)
    |-- TodoStore, LogSeqParser, FileWatcher
    |-- DigestFileManager, StorageManager, GitSyncService
    |
  Networking/      (library, depends: Models)
    |-- KeychainHelper, LinearAPIClient, PylonAPIClient
    |-- APISyncService, DigestWriter protocol, SyncModels
    |
  MCP/             (library, depends: Models, Services, Networking)
    |-- MCPServer, JSONRPCTypes
    |
  App/             (executable, depends: all)
    |-- main.swift, LogSeqTodosApp
    |-- Views/, ViewModels/, Extensions/
```

## Dependency Graph

```
Models (0 deps)          pure data types, Foundation-only
  ^         ^
  |         |
Services    Networking   file I/O, parsing   |   HTTP, Keychain
  ^    ^      ^    ^
  |    +--+---+    |
  |       |        |
  |      MCP       |     JSON-RPC server over stdin/stdout
  |       ^        |
  +-------+--------+
          |
    LogSeqTodos          SwiftUI app, menu bar popover
```

## Key Design Decisions

- **Models imports only Foundation** - SwiftUI properties (Color, icon names) live in `App/Extensions/` as extensions on model types
- **Services uses `import Observation`** not SwiftUI - `@Observable` works without SwiftUI on macOS 14+
- **Networking is decoupled from Services** via the `DigestWriter` protocol - the App wires them together
- **MCP server accepts dependencies via init** - `DigestFileManager` is injected, not created internally

## Data Flow

```
Markdown files (journals/*.md, pages/*.md)
       |
  LogSeqParser.parseFile()
       |
  [TodoItem] array
       |
  TodoStore (sorts, caches, watches for changes)
       |
  TodoListViewModel (filters, groups, search)
       |
  SwiftUI Views (MenuPopoverView, TodoRowView, etc.)
```

## API Sync Flow

```
Linear/Pylon APIs
       |
  LinearAPIClient / PylonAPIClient (async fetch)
       |
  APISyncService (orchestrator, periodic timer)
       |
  DigestWriter.writeDigest() --> pages/linear-digest.md, pages/pylon-digest.md
       |
  FileWatcher detects change --> TodoStore.reload()
```

## MCP Server

Runs as headless process via `--mcp` flag. JSON-RPC 2.0 over stdin/stdout.

**Tools:**
- `list_todos` - query todos with filters
- `add_todo` - add to today's journal
- `update_todo` - change task status
- `add_source_todo` - add to Linear/Pylon digest (deduplicates by UUID)
- `remove_todo` - delete a line from a file
- `sync_source` - bulk-replace digest file (deduplicates by UUID)

## Storage Modes

- **LogSeq mode** - reads/writes from a configured LogSeq graph path
- **Standalone mode** - uses `~/.logseq-todos/` with same directory structure
- **Git sync** - auto commit+push on configurable interval if a git remote is detected

## Settings (UserDefaults keys)

| Key | Purpose |
|-----|---------|
| `logseq.graphPath` | LogSeq graph directory |
| `filterMode`, `groupMode` | UI filter/group state |
| `showCompleted` | Toggle completed items |
| `sourceFilter` | Active source filter |
| `sourceOrder` | Source priority order (JSON) |
| `autoRefreshInterval` | File watch poll interval |
| `enabledMarkersData` | Visible task markers (JSON) |
| `api.linearEnabled`, `api.pylonEnabled` | API sync toggles |
| `api.syncInterval` | API sync interval (minutes) |
| `git.enabled` | Git sync toggle |
| `git.syncInterval` | Git sync interval (minutes) |
| `git.commitTemplate` | Commit message template |

API tokens stored in macOS Keychain (service: `com.logseqtodos.api-tokens`).
