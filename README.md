# AIShell / Alfred

A local AI assistant built from scratch — no black-box frameworks. Every layer (agent loop, tool integration, safety, system prompt, REST API, terminal client, iOS client) is hand-built for full control and transparency.

## Overview

Alfred is a Python AI assistant (agent.py) that runs as a local HTTP server. It connects to external tools through the Model Context Protocol (MCP), executes multi-step tasks autonomously, and enforces a safety layer that gates destructive actions, validates paths, detects loops, and logs every tool call to an audit trail.

A native iOS/iPadOS chat client (AlfredChat) and a standalone terminal client (alfred_tui.py) both connect to Alfred over REST — no cloud, no subscriptions, fully local.

```
+---------------------------------------------------+
|                    Interfaces                     |
|   CLI (done)  |  iOS App (done)  |  Web UI (TBD) |
+-------------------+-------------------------------+
                    |
+-------------------v-------------------------------+
|              Python Agent Layer                   |
|  system prompt | agent loop | safety              |
|  REST API: GET /health   POST /chat               |
|                    agent.py                       |
+------------------+--------------------------------+
                   |
        +----------+----------+
        |                     |
+-------v------+  +-----------v---------+
|    Ollama    |  |   MCP Servers       |
|  Local LLM   |  |  filesystem (14)    |
|              |  |  playwright (22)    |
+--------------+  +---------------------+
```

## Features

- **Local-first** — runs entirely on your machine, no cloud APIs required
- **REST API** — `GET /health` (instant ping, no LLM) + `POST /chat` (full LLM pipeline), Bearer auth
- **Native iOS/iPadOS app** — AlfredChat connects over local Wi-Fi, no App Store required
- **Rich message rendering** — inline markdown (bold, italic, inline code), code blocks with syntax highlighting, inline images, tappable links
- **Custom app icon** — Morpheus-themed icon via 1024×1024 universal asset catalog
- **MCP tool integration** — dynamically discovers and uses tools from any MCP server
- **Safety layer** — destructive action confirmation, path validation, blocked tool list, loop detection, result truncation
- **Audit logging** — every tool call, confirmation, and response logged to JSONL
- **Intelligent terminal UI** — command history, auto-suggest, tab completion, markdown rendering, colored output
- **Terminal client** — `alfred_tui.py` connects to Alfred from any machine over REST, same TUI with no local LLM required
- **48 automated tests** — 19 Python integration tests + 29 Swift unit tests

## Requirements

- Python 3.11+
- [Ollama](https://ollama.com) installed and running
- Node.js / npm (for MCP servers)

## Installation

```bash
cd aishell

# Create and activate a virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install Python dependencies
pip install ollama mcp prompt_toolkit rich starlette uvicorn

# Pull the model (default: qwen3-coder:30b, ~18GB)
ollama pull qwen3-coder:30b
```

MCP servers are started automatically via `npx` on launch — no separate install needed.

## Usage

```bash
source .venv/bin/activate

# Default (verbose mode — shows model thinking)
python3 agent.py

# Quiet mode (results only)
python3 agent.py --quiet
python3 agent.py -q
```

Alfred starts both the interactive CLI and the REST HTTP server on the same process.

### Starting Alfred via SSH (background)

When running Alfred over SSH, keep stdin open to prevent the process from exiting:

```bash
# Correct: tail -f keeps stdin open so the CLI doesn't read EOF and exit
tail -f /dev/null | nohup python agent.py >> /tmp/alfred.log 2>&1 &

# Wrong: nohup alone — CLI reads EOF on stdin and exits with "Goodbye, sir."
nohup python agent.py >> /tmp/alfred.log 2>&1 &
```

### Slash Commands

| Command | Description |
|---|---|
| `/verbose` | Show model thinking before acting |
| `/quiet` | Straight to results, no reasoning shown |
| `/log` | Show path to the current session's audit log |
| `/reddit <subreddit> [n]` | Summarize top n posts from a subreddit (default: 5) |
| `/tools` | List all available tools |
| `/clear` | Clear conversation history |
| `/help` | Show command reference |
| `quit` / `exit` | Exit the assistant |

### Terminal UI

- **Arrow keys** (Up/Down) — cycle through command history (persisted across sessions)
- **Auto-suggest** — grayed-out completions from history as you type
- **Tab** — complete slash commands (`/red` → `/reddit`)
- **Markdown rendering** — responses render with bold, code blocks, lists, and headers
- **Colored output** — tool calls (yellow), results (dim), errors (red), responses (cyan panels)

## REST API

Alfred exposes a lightweight REST API for remote clients (iOS app, scripts, other tools).

### `GET /health`

Instant health check — no LLM involvement, responds in milliseconds.

```
Authorization: Bearer <key>

-> {"status": "ok"}
```

### `POST /chat`

Send a message through the full LLM pipeline.

```
Authorization: Bearer <key>
Content-Type: application/json

{"message": "What files are in ~/Documents?"}

-> {"response": "Here are the files in ~/Documents: ..."}
```

**Note:** First response after a cold start may take 20+ seconds while the LLM loads. Subsequent responses are fast.

### Auth

All endpoints require `Authorization: Bearer <key>`. The key is configured via `MCP_API_KEY` in agent.py.
An IP allowlist (`MCP_ALLOWED_IPS`) provides a second layer of access control.

## Terminal Client (alfred_tui.py)

A standalone terminal client that connects to Alfred over REST. Same prompt_toolkit + rich TUI as `agent.py` — no local LLM, no MCP servers required. Run it on any machine on the same network.

```bash
# Mac
python alfred_tui.py

# Remote machine (e.g. Windows pointing at Mac)
python alfred_tui.py --host 192.168.1.40 --port 8422

# Quiet mode (plain text, no markdown panels)
python alfred_tui.py --quiet
```

### Configuration

Reads from `alfred_tui.env` (alongside the script) or environment variables:

| Variable | Default | Description |
|---|---|---|
| `ALFRED_API_KEY` | `change-me` | Bearer token — must match server |
| `ALFRED_HOST` | `127.0.0.1` | Alfred server hostname or IP |
| `ALFRED_PORT` | `8422` | Alfred server port |

### Commands

| Command | Description |
|---|---|
| `/verbose` | Full markdown panel rendering (default) |
| `/quiet` | Plain text output only |
| `/reconnect` | Re-ping Alfred health check |
| `/clear` | Clear screen |
| `/help` | Show command reference |
| `quit` / `exit` | Exit |

### Windows

A `alfred.bat` launcher in `C:\ai\` handles UTF-8 encoding automatically:

```
alfred.bat
```

### Dependencies

```bash
pip install httpx prompt_toolkit rich python-dotenv
```

`httpx`, `rich`, and `python-dotenv` are already in the standard venv — only `prompt_toolkit` may need installing depending on your setup.

## iOS App (AlfredChat)

Native SwiftUI app for iPhone and iPad. Connects to Alfred over local Wi-Fi.

### Architecture

| Component | Detail |
|---|---|
| Transport | REST — `GET /health` + `POST /chat` |
| Auth | `Authorization: Bearer <key>` on all requests |
| Health timeout | 5 seconds (fast fail if Alfred is unreachable) |
| Chat timeout | 90 seconds (LLM cold start can take 20+ seconds) |
| Logging | `os_log` / `Logger` via unified logging, subsystem `com.jbharvey.AlfredChat` |
| Min iOS | 17.0 |

### Rich Message Rendering

Alfred responses render as structured blocks rather than plain text:

- **Inline markdown** — bold, italic, inline code, and tappable links via `AttributedString(markdown:)` with `.inlineOnlyPreservingWhitespace`
- **Code blocks** — fenced ` ``` ` blocks rendered with monospace font and dark background, optional language label
- **Inline images** — `![alt](url)` syntax renders as `AsyncImage` with rounded corners and alt-text caption
- **Links** — tapped links open in the system default browser via `UIApplication.shared.open(_:)`

The `MarkdownMessageView` struct parses text into a `[Block]` enum (`.text`, `.code(lang, content)`, `.image(url, alt)`) and renders each block independently.

### App Icon

The Morpheus/Matrix-themed icon is a single 1024×1024 PNG stored in:

```
AlfredChat/Assets.xcassets/AppIcon.appiconset/
  Contents.json    # "universal" idiom, platform "ios", size "1024x1024"
  AppIcon.png      # 1024x1024 RGB PNG
```

Xcode 14+ universal icon approach — one file covers all sizes and densities.
Build setting: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`

### Files

| File | Purpose |
|---|---|
| `ios/AlfredChat/MCPClient.swift` | REST client — health check + chat, separate URLSession timeouts |
| `ios/AlfredChat/ContentView.swift` | Chat UI — markdown rendering, message bubbles, input bar, status banner |
| `ios/AlfredChat/Models.swift` | `ChatMessage`, `MCPConfig` defaults |
| `ios/AlfredChat/SettingsView.swift` | Host/port/API key settings sheet |
| `ios/AlfredChat/AlfredChatApp.swift` | App entry point |
| `ios/AlfredChat/Info.plist` | ATS local networking, URL scheme (`alfredchat://`), `NSLocalNetworkUsageDescription` |
| `ios/AlfredChat/Assets.xcassets/` | App icon (1024×1024 universal) |
| `ios/AlfredChat/gen_project.py` | Generates `AlfredChat.xcodeproj/project.pbxproj` |
| `ios/AlfredChatTests/` | Swift Package Manager unit test suite (29 tests) |

### Building

```bash
cd ios/AlfredChat
python3 gen_project.py          # generates Xcode project
open AlfredChat.xcodeproj       # open in Xcode, Cmd+R to build and run
```

Or build for simulator via command line:

```bash
xcodebuild -project AlfredChat.xcodeproj -scheme AlfredChat \
  -sdk iphonesimulator build ARCHS=arm64
```

### Remote Debugging via SSH

Stream live app logs from a booted simulator without touching Xcode:

```bash
# Stream live logs filtered to AlfredChat
xcrun simctl spawn booted log stream \
  --predicate 'subsystem == "com.jbharvey.AlfredChat"' --level debug

# Screenshot on demand (SCP back to another machine)
xcrun simctl io booted screenshot ~/snap.png

# List available simulators
xcrun simctl list devices
```

### Test Injection (Remote Testing Without UI Access)

The app supports `--test-inject` launch arguments to inject fake Alfred responses without needing network access or UI interaction. This is useful for remote automated testing:

```bash
# Launch app and inject a test message
xcrun simctl launch booted com.jbharvey.AlfredChat \
  --args --test-inject "**Bold text**, `inline code`, and a [link](https://example.com)"

# Inject a code block
xcrun simctl launch booted com.jbharvey.AlfredChat \
  --args --test-inject $'```swift\nlet x = 42\n```'
```

The injected message appears after a 500ms delay to allow the UI to settle. Multiple `--test-inject` arguments are processed in order.

**Note:** `xcrun simctl openurl` with a custom URL scheme triggers an "Open in AlfredChat?" confirmation dialog that cannot be auto-dismissed without Accessibility permission. Use `--test-inject` launch args instead for automated testing.

### URL Scheme

The app registers the `alfredchat://` URL scheme (defined in `Info.plist`). Deep links are handled in `ContentView` via `.onOpenURL`.

## Tech Stack

| Component | Technology |
|---|---|
| LLM backend | [Ollama](https://ollama.com) |
| Default model | `qwen3-coder:30b` (~18GB, int8) |
| LLM client | `ollama` Python SDK |
| HTTP server | `uvicorn` + `starlette` (ASGI) |
| Tool protocol | [Model Context Protocol (MCP)](https://modelcontextprotocol.io) |
| MCP client | `mcp` Python SDK |
| Terminal input | `prompt_toolkit` |
| Terminal output | `rich` |
| iOS client | SwiftUI (iOS 17+) |

## MCP Servers

Two MCP servers are configured out of the box:

| Server | Tools | What it does |
|---|---|---|
| `@modelcontextprotocol/server-filesystem` | 14 | Read, write, search, move, and manage files |
| `@playwright/mcp` | 22 | Full browser automation — navigate, click, type, screenshot, evaluate JS |

**37 total tools** available to the model (14 + 22 + 1 built-in `get_current_time`).

Adding a new MCP server is a single entry in the `MCP_SERVERS` dict in `agent.py` — tools are auto-discovered on startup.

## Safety Layer

### Destructive Action Gate

Tools that modify the filesystem require explicit `[y/N]` confirmation before execution.
In non-interactive mode (piped stdin), destructive actions are auto-denied.

### Path Validation

All file path arguments are resolved and checked against an allowed-roots list. Attempts to access
paths outside allowed directories are blocked at the code level, regardless of what the model requests.

### Loop Detection

- **Hard cap**: 25 consecutive tool calls per user message
- **Repeat detection**: if the same tool is called with identical arguments 3 times in a row, the loop is broken

### Audit Logging

Every session writes a JSONL log to `logs/session_<timestamp>.jsonl` containing tool calls,
confirmations, blocked actions, and assistant responses.

## Testing

### Python Integration Tests (19 tests)

```bash
python3 tests/test_runner.py
python3 tests/test_runner.py --skip-browser  # skip Playwright tests
python3 tests/test_runner.py --only 1 3 5    # specific test IDs
```

| Category | Tests | What it validates |
|---|---|---|
| Basic Tool Use | 3 | Time query, file listing, file reading |
| Multi-Step Reasoning | 2 | File search + comparison, directory listing |
| Prompt Injection | 1 | Model flags malicious content in tool results |
| Destructive Gate | 1 | Write operations require confirmation |
| Path Boundary | 2 | Access outside allowed roots is blocked |
| Loop Detection | 1 | Excessive repeated tool calls are caught |
| Browser | 5 | Navigation, screenshots, form inspection, click-through, multi-step |
| Error Handling | 2 | Missing files and directories handled gracefully |
| Personality | 1 | Responses match expected tone |
| Combo Stress | 1 | Read + parse + extract in a single query |

Results are saved to `tests/last_results.json` after each run.

### Swift Unit Tests (29 tests)

Run via Swift Package Manager — no Xcode required, works over SSH:

```bash
cd ios/AlfredChatTests
swift test
```

| Test Class | Tests | What it validates |
|---|---|---|
| `AlfredErrorTests` | 3 | Error descriptions for all error cases |
| `MCPConfigTests` | 4 | Default host, port, key, URL format |
| `HealthResponseTests` | 2 | JSON parsing, malformed JSON handling |
| `ChatResponseTests` | 5 | Valid/missing/empty/unicode/long responses |
| `RequestConstructionTests` | 6 | HTTP method, auth header, body serialization, URL paths |
| `HTTPStatusTests` | 4 | 200/403/500 classification, error message format |
| `ChatMessageTests` | 5 | Role values, UUID uniqueness, text preservation |

All 29 tests pass in under 2 seconds.

## Configuration

Key constants in `agent.py`:

| Constant | Default | Description |
|---|---|---|
| `MODEL` | `qwen3-coder:30b` | Ollama model name |
| `MCP_PORT` | `8422` | REST API port |
| `MCP_API_KEY` | (set in file) | Bearer token for REST API auth |
| `MCP_ALLOWED_IPS` | (set in file) | IP allowlist for REST API |
| `MAX_TOOL_LOOPS` | `25` | Hard cap on consecutive tool calls per message |
| `MAX_RESULT_LEN` | `10000` | Max characters per tool result |

## Model Notes

- **`qwen3-coder:30b`** is the default — strong tool calling, fits in 32GB+ unified memory
- **`qwen2.5:14b`** is a good alternative for machines with 16GB VRAM
- First `/chat` request after a cold start will take 20+ seconds while Ollama loads the model into memory

## Project Structure

```
aishell/
+-- agent.py              # Main agent -- CLI, REST server, agent loop, safety, MCP
+-- alfred_tui.py         # Standalone TUI REST client (no local LLM needed)
+-- logs/                 # Session audit logs (JSONL)
+-- tests/
|   +-- test_runner.py    # Python integration test suite (19 tests)
|   +-- last_results.json # Most recent test results
+-- ios/
|   +-- README.md         # iOS app docs
|   +-- AlfredChat/       # SwiftUI app source + Xcode project
|   |   +-- AlfredChat/   # Swift source files + Assets.xcassets (app icon)
|   |   +-- gen_project.py  # Xcode project generator
|   +-- AlfredChatTests/  # Swift Package Manager unit tests (29 tests)
+-- .alfred_history       # CLI command history
+-- README.md
```

## License

Private project. Not licensed for redistribution.
