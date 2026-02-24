# LogSeq Todos

A macOS menu bar app for managing todo items stored as LogSeq-compatible markdown. Ships with a built-in **MCP server** (Model Context Protocol) so AI agents can read, create, update, and sync todos programmatically.

## Quick Start (MCP)

Add to your MCP client config (e.g. `.mcp.json`):

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

Optional flags:
- `--graph-path /path/to/graph` — override the LogSeq graph directory (default: reads from UserDefaults key `logseq.graphPath`, fallback `~/.logseq-todos/`)

The server speaks **JSON-RPC 2.0** over stdin/stdout, protocol version `2024-11-05`.

## MCP Tools

### `list_todos`

Query todos with filters. Returns formatted text with status, content, priority, tags, page refs, dates, source file path, and line number.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filter` | string | no | `"active"` (default), `"all"`, `"today"`, `"overdue"`, `"done"` |
| `search` | string | no | Text search across content, tags, and page references |
| `tag` | string | no | Filter by tag name (without `#`) |
| `source` | string | no | `"manual"`, `"linear"`, or `"pylon"` |
| `limit` | number | no | Max items to return (default: 50) |

### `add_todo`

Add a new TODO to today's journal file (`journals/YYYY_MM_DD.md`). Prepends the item.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `text` | string | **yes** | The todo text |
| `priority` | string | no | `"A"` (high), `"B"` (medium), `"C"` (low) |

### `update_todo`

Change the status marker of an existing todo. Use `file_path` and `line_number` from `list_todos` output.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file_path` | string | **yes** | Absolute path to the markdown file |
| `line_number` | number | **yes** | 0-based line number |
| `new_status` | string | **yes** | `TODO`, `DOING`, `DONE`, `NOW`, `LATER`, `WAITING`, `CANCELLED` |

### `add_source_todo`

Add a todo to a source-specific digest page (`pages/linear-digest.md` or `pages/pylon-digest.md`). **Deduplicates by `source_id`** — if the UUID already exists in the file, the call returns a skip message instead of creating a duplicate.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `source` | string | **yes** | `"linear"` or `"pylon"` |
| `text` | string | **yes** | Item text (e.g. issue title) |
| `source_id` | string | no | Tracking UUID (Linear/Pylon issue ID) |
| `url` | string | no | Link to open in source app |
| `identifier` | string | no | Short label (e.g. `EXT-42`, `#491`) |
| `priority` | string | no | `"A"`, `"B"`, `"C"` |

### `remove_todo`

Delete a line from a file entirely. Useful for cleaning up stale items.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file_path` | string | **yes** | Absolute path to the markdown file |
| `line_number` | number | **yes** | 0-based line number |

### `sync_source`

Bulk-replace a source digest file with a fresh set of items. Wipes the file and writes all items. **Deduplicates within the input array by `source_id`** — if two items share the same UUID, only the first is kept.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `source` | string | **yes** | `"linear"` or `"pylon"` |
| `items` | array | **yes** | Array of item objects (see below) |

Each item in the `items` array:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | **yes** | Item text |
| `source_id` | string | no | Tracking UUID |
| `url` | string | no | Link URL |
| `identifier` | string | no | Short label |
| `status` | string | no | Marker (default: `TODO`) |
| `priority` | string | no | `"A"`, `"B"`, `"C"` |

## Markdown Format

Todos are stored as LogSeq-compatible markdown:

```markdown
- TODO Buy groceries
- TODO [#A] Fix critical bug #work
- DONE [#B] [EXT-42 Review PR](https://linear.app/...) #linear linear:uuid-here
- WAITING Deploy to staging SCHEDULED: <2024-03-15> DEADLINE: <2024-03-20>
```

### Task markers

`TODO` | `DOING` | `DONE` | `NOW` | `LATER` | `WAITING` | `CANCELLED`

Active markers (appear in default `active` filter): `TODO`, `DOING`, `NOW`, `LATER`, `WAITING`

### Priority

`[#A]` = high, `[#B]` = medium, `[#C]` = low. Placed after the marker.

### Source tracking

Digest items include a source tag and tracking ID: `#linear linear:<uuid>` or `#pylon pylon:<uuid>`. The UUID is used for deduplication.

### Dates

- `SCHEDULED: <YYYY-MM-DD>` — when to start
- `DEADLINE: <YYYY-MM-DD>` — due date

## File Structure

```
<graph-path>/
  journals/
    2024_01_15.md        # daily journal files (manual todos)
    2024_01_16.md
  pages/
    linear-digest.md     # Linear issues synced via API or MCP
    pylon-digest.md      # Pylon issues synced via API or MCP
    any-other-page.md    # todos from any LogSeq page
```

The server scans all `.md` files in `journals/` and `pages/` when listing todos.

## Building

```bash
swift build
```

The binary is at `.build/debug/LogSeqTodos`. Run with `--mcp` for headless MCP mode, or without flags for the GUI app.

Requires macOS 14+ and Swift 5.9+.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full module dependency graph, data flow, and design decisions.

Five SPM targets: `Models` (pure data) -> `Services` (file I/O, parsing) + `Networking` (HTTP, Keychain) -> `MCP` (JSON-RPC server) -> `LogSeqTodos` (SwiftUI app).
