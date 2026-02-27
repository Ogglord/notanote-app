# NotaNote - Architecture

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
    |-- APISyncService, NotificationService
    |-- DigestWriter protocol, SyncModels
    |
  MCP/             (library, depends: Models, Services, Networking)
    |-- MCPServer, JSONRPCTypes
    |
  App/             (executable, depends: all)
    |-- main.swift, NotaNoteApp
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
    NotaNote             SwiftUI app, menu bar popover
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

## Notification Flow

```
Linear Inbox API (notifications query) / Pylon new-issue detection
       |
  APISyncService.syncNotifications() (runs after main sync)
       |
  NotificationService (tracks seen IDs in UserDefaults, detects new items)
       |
  ├── DigestWriter.writeNotifications() --> pages/notifications.md
  ├── UNUserNotificationCenter (native macOS banners via NotificationDelegate)
  └── unreadCount --> menu bar badge indicator (dot)
```

- Linear inbox: fetches last 10 notifications via `notifications` GraphQL query
- Pylon: compares current issues against previously seen IDs
- Seen IDs capped at 200 per source to prevent unbounded UserDefaults growth
- NotificationDelegate enables banners even when app is in foreground

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
| `notifications.enabled` | Notification sync toggle |
| `notifications.native` | Native macOS notification banners toggle |
| `notifications.seenLinearIds` | Previously seen Linear notification IDs |
| `notifications.seenPylonIds` | Previously seen Pylon issue IDs |

API tokens stored in macOS Keychain (service: `com.notanote.api-tokens`).
