# AIShell / Alfred

[![Follow on X](https://img.shields.io/badge/follow-%40boschzilla-black.svg?logo=x)](https://x.com/boschzilla)

A local AI assistant built from scratch — no black-box frameworks. Every layer (agent loop, tool integration, safety, system prompt, REST API, MCP server, terminal client, iOS client) is hand-built for full control and transparency.

## Overview

Alfred is a Python AI assistant (`agent.py`) that runs as a local HTTP server. It connects to external tools through the Model Context Protocol (MCP), executes multi-step tasks autonomously, and enforces a safety layer that gates destructive actions, validates paths, detects loops, and logs every tool call to an audit trail.

It also exposes its own MCP server over SSE, allowing external LLMs (Claude Code, other agents) to connect and interact with the conversation transparently.

A native iOS/iPadOS chat client (AlfredChat) and a standalone terminal client (`alfred_tui.py`) both connect to Alfred over REST — no cloud, no subscriptions, fully local.

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
|  MCP SSE server: send_message / read_history      |
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
- **REST API** — `GET /health` (instant ping) + `POST /chat` (full LLM pipeline), Bearer auth
- **MCP server** — exposes the conversation over SSE so external LLMs can inject messages, read history, and interject context
- **Native iOS/iPadOS app** — AlfredChat connects over local Wi-Fi, no App Store required
- **Terminal client** — `alfred_tui.py` connects to Alfred from any machine over REST
- **Rich message rendering** — inline markdown (bold, italic, inline code), code blocks with syntax highlighting, inline images, tappable links
- **MCP tool integration** — dynamically discovers and uses tools from any MCP server
- **Safety layer** — destructive action confirmation, path validation, blocked tool list, loop detection, result truncation
- **Audit logging** — every tool call, confirmation, and response logged to JSONL
- **Conversation log** — persistent, human-readable `conversation.log` across all sessions
- **Intelligent terminal UI** — command history, auto-suggest, tab completion, markdown rendering, colored output
- **Network auth** — IP allowlist + API key (Bearer token), timing-safe comparison
- **XML tool call fallback** — handles models that emit raw XML instead of using the structured API
- **Reddit scraper** — built-in `/reddit` command for subreddit summarization via Playwright

## Requirements

- Python 3.11+
- [Git](https://git-scm.com)
- [Ollama](https://ollama.com) installed and running
- Node.js 18+ / npm (for MCP servers)

### Hardware Recommendations

| Model | RAM | Disk (OS + tools + model) | Notes |
|-------|-----|--------------------------|-------|
| `qwen2.5:0.5b` | 8GB+ | 40GB+ | Minimum viable — slow, basic quality |
| `qwen2.5:3b` | 16GB+ | 50GB+ | Decent quality, usable on CPU |
| `qwen2.5:14b` | 16GB+ VRAM or 32GB RAM | 60GB+ | Good quality, GPU recommended |
| `qwen3-coder:30b` (default) | 32GB+ unified/VRAM | 60GB+ | Best quality, requires GPU |
| `qwen2.5:72b` | 64GB+ | 80GB+ | Maximum quality |

**GPU strongly recommended** for models 3b and above. CPU-only inference works but is very slow (minutes per response with full tool context).

## New Machine Setup

### macOS / Linux

**1. Install Homebrew (macOS only)**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**2. Install Ollama**
```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh
```

Start the Ollama server (runs in background):
```bash
ollama serve &
```

**3. Install Node.js**
```bash
# macOS
brew install node

# Linux (using nvm — recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install --lts
```

**4. Clone and set up Python environment**
```bash
# Linux only — install venv if not already present
sudo apt install python3-venv  # Debian/Ubuntu

git clone https://github.com/jbharvey1/aishell.git
cd aishell

python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt
```

**5. Pull the model**
```bash
# Default model (~18GB — requires 32GB+ RAM or VRAM)
ollama pull qwen3-coder:30b

# Lighter alternative (~9GB — requires 16GB RAM)
ollama pull qwen2.5:14b

# Lightweight (~2GB — requires 8GB+ RAM, runs on CPU)
ollama pull qwen2.5:3b
```

See [Hardware Recommendations](#hardware-recommendations) for guidance on which model to choose.

**6. Configure**
```bash
cp .env.example .env
```

Open `.env` in an editor and set:
- `ALFRED_API_KEY` — any password you choose (protects the REST API)
- `ALFRED_MODEL` — the model you pulled in step 5 (e.g. `qwen2.5:14b`). Leave as `qwen3-coder:30b` if you pulled the default.

**7. Run Alfred**
```bash
source .venv/bin/activate
python3 agent.py
```

Alfred starts the CLI and REST server on port 8422. To keep it running in the background (e.g. over SSH):
```bash
tail -f /dev/null | nohup python3 agent.py >> /tmp/alfred.log 2>&1 &
```

> **Note:** `tail -f /dev/null` keeps stdin open so the CLI doesn't exit immediately when run non-interactively. Plain `nohup` alone causes the CLI to read EOF and exit.

---

### Windows

Windows is fully supported — both the **agent/server** (`agent.py`) and the **terminal client** (`alfred_tui.py`) work on Windows.

**1. Install prerequisites**

You need four things: Python, Git, Node.js, and Ollama. The easiest way is via winget — open a terminal and run:

```bat
winget install Python.Python.3.12 --source winget
winget install Git.Git --source winget
winget install OpenJS.NodeJS.LTS --source winget
winget install Ollama.Ollama --source winget
```

Or download installers manually: [Python](https://www.python.org/downloads/) (check "Add to PATH"), [Git](https://git-scm.com/download/win), [Node.js LTS](https://nodejs.org/), [Ollama](https://ollama.com).

> **Important:** Close and reopen your terminal after installing so the new programs are on your PATH.

**2. Start Ollama and pull a model**

Open a terminal and start the Ollama service:
```bat
ollama serve
```

Leave that running and open a **second terminal**. Choose a model based on your hardware (see [Hardware Recommendations](#hardware-recommendations)):

```bat
:: 16GB+ RAM with GPU — best quality (default)
ollama pull qwen3-coder:30b

:: 16GB RAM, no GPU — good balance
ollama pull qwen2.5:3b

:: 8GB RAM — lightweight, basic quality
ollama pull qwen2.5:0.5b
```

**3. Clone and install**
```bat
git clone https://github.com/jbharvey1/aishell.git
cd aishell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

**4. Configure**
```bat
copy .env.example .env
```

Open `.env` in a text editor and change two things:
- `ALFRED_API_KEY` — set to any password you choose (e.g. `mysecretkey`). This protects the REST API.
- `ALFRED_MODEL` — set to the model you pulled in step 2 (e.g. `qwen2.5:3b`). Leave as `qwen3-coder:30b` if you pulled the default.

**5. Run Alfred**
```bat
python agent.py
```

Alfred will connect to its MCP tool servers (filesystem + browser automation), then drop you into an interactive chat. The REST API starts automatically on port 8422.

> **Tip:** If you see Unicode errors in the terminal, run `set PYTHONIOENCODING=utf-8` before launching, or use `chcp 65001` to switch your terminal to UTF-8.

**Connecting from another machine (terminal client only)**

If Alfred is already running on another machine and you just want a chat client:
```bat
python alfred_tui.py --host <alfred-ip> --port 8422
```

---

## Configuration

All secrets are loaded from `.env` (gitignored) via `python-dotenv`. Never hardcoded.

| Variable | Description | Example |
|---|---|---|
| `ALFRED_API_KEY` | Bearer token required on all REST and MCP endpoints | `your-secret-key` |
| `ALFRED_ALLOWED_IPS` | Comma-separated extra IPs allowed (localhost always included) | `192.168.1.251,192.168.1.166` |
| `ALFRED_MODEL` | Ollama model to use (default: `qwen3-coder:30b`) | `qwen2.5:14b` |
| `ALFRED_HOST` | Bind address (default: `127.0.0.1` — localhost only) | `0.0.0.0` |

See `.env.example` in the repo for the template.

---

## Usage

```bash
source .venv/bin/activate

# Default (verbose mode — shows model thinking)
python3 agent.py

# Quiet mode (results only)
python3 agent.py --quiet
python3 agent.py -q

# Use a different model
python3 agent.py --model qwen2.5:14b

# Custom MCP server port
python3 agent.py --port 9000

# Disable MCP SSE server
python3 agent.py --no-server
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

---

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

---

## MCP Server (External LLM Bridge)

On startup, `agent.py` also launches an SSE-based MCP server on port **8422**. External LLMs connect to this server and interact with the conversation as another participant.

### Exposed Tools

| Tool | Description |
|---|---|
| `send_message` | Inject a message into the conversation, get Alfred's full response (runs through the complete agent loop — tools, safety, audit) |
| `read_history` | Read the last N messages from the conversation |
| `get_status` | Returns model name, tool count, verbose mode, message count, audit log path |
| `interject` | Inject a system-level note without triggering a response |

### Connecting from Claude Code

Add to your MCP client config (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "alfred": {
      "url": "http://<alfred-host>:8422/sse",
      "headers": {
        "Authorization": "Bearer <your-api-key>"
      }
    }
  }
}
```

---

## Terminal Client (alfred_tui.py)

A standalone terminal client that connects to Alfred over REST. Same `prompt_toolkit` + `rich` TUI as `agent.py` — no local LLM, no MCP servers required. Run it on any machine on the same network.

```bash
# Mac / Linux
python3 alfred_tui.py

# Point at a specific Alfred host
python3 alfred_tui.py --host <alfred-host> --port 8422

# Quiet mode (plain text)
python3 alfred_tui.py --quiet
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

### Dependencies

```bash
pip install httpx prompt_toolkit rich python-dotenv
```

---

## iOS App (AlfredChat)

Native SwiftUI app for iPhone and iPad. Connects to Alfred over local Wi-Fi.

### Architecture

| Component | Detail |
|---|---|
| Transport | REST — `GET /health` + `POST /chat` |
| Auth | `Authorization: Bearer <key>` on all requests |
| Health timeout | 5 seconds (fast fail if Alfred is unreachable) |
| Chat timeout | 90 seconds (LLM cold start can take 20+ seconds) |
| Min iOS | 17.0 |

### Rich Message Rendering

Alfred responses render as structured blocks rather than plain text:

- **Inline markdown** — bold, italic, inline code, and tappable links via `AttributedString(markdown:)`
- **Code blocks** — fenced ` ``` ` blocks rendered with monospace font and dark background, optional language label
- **Inline images** — `![alt](url)` syntax renders as `AsyncImage` with rounded corners and alt-text caption
- **Links** — tapped links open in the system default browser

### Building

```bash
cd ios/AlfredChat
python3 gen_project.py          # generates Xcode project
open AlfredChat.xcodeproj       # open in Xcode, Cmd+R to build and run
```

Or for simulator via command line:

```bash
xcodebuild -project AlfredChat.xcodeproj -scheme AlfredChat \
  -sdk iphonesimulator build ARCHS=arm64
```

### Remote Debugging via SSH

```bash
# Stream live app logs
xcrun simctl spawn booted log stream \
  --predicate 'subsystem == "com.jbharvey1.AlfredChat"' --level debug

# Screenshot on demand
xcrun simctl io booted screenshot ~/snap.png
```

### Test Injection (Headless UI Testing)

The app supports `--test-inject` launch arguments to inject fake Alfred responses into the simulator without needing network access or UI interaction:

```bash
xcrun simctl launch booted com.jbharvey1.AlfredChat \
  --args --test-inject "**Bold text**, \`inline code\`, and a [link](https://example.com)"
```

The injected message appears after a 500ms delay to allow the UI to settle.

### Files

| File | Purpose |
|---|---|
| `ios/AlfredChat/MCPClient.swift` | REST client — health check + chat, separate URLSession timeouts |
| `ios/AlfredChat/ContentView.swift` | Chat UI — markdown rendering, message bubbles, input bar, status banner |
| `ios/AlfredChat/Models.swift` | `ChatMessage`, `MCPConfig` defaults |
| `ios/AlfredChat/SettingsView.swift` | Host/port/API key settings sheet |
| `ios/AlfredChat/AlfredChatApp.swift` | App entry point |
| `ios/AlfredChat/Info.plist` | ATS local networking, `NSLocalNetworkUsageDescription` |
| `ios/AlfredChat/Assets.xcassets/` | App icon (1024×1024 universal) |
| `ios/AlfredChat/gen_project.py` | Generates `AlfredChat.xcodeproj/project.pbxproj` |
| `ios/AlfredChatTests/` | Swift Package Manager unit test suite (29 tests) |

---

## MCP Servers (Client Side)

Two MCP servers are configured out of the box as tool sources:

| Server | Tools | What it does |
|---|---|---|
| `@modelcontextprotocol/server-filesystem` | 14 | Read, write, search, move, and manage files |
| `@playwright/mcp` | 22 | Full browser automation — navigate, click, type, screenshot, evaluate JS |

**37 total tools** available to the model (14 + 22 + 1 built-in `get_current_time`).

Adding a new MCP server is a single entry in the `MCP_SERVERS` dict in `agent.py` — tools are auto-discovered on startup.

> **Note:** MCP servers are launched via `npx`. On macOS over SSH (without a login shell), `npx` may not be on `PATH` — `agent.py` uses the full path `/opt/homebrew/bin/npx` and passes a corrected `PATH` env. On Windows, `npx.cmd` is used instead. This is handled automatically via platform detection.

---

## Security Model

Alfred's REST API and MCP server implement defense-in-depth:

| Layer | Default | Purpose |
|-------|---------|---------|
| **TLS** | Self-signed HTTPS | Encrypts all traffic — API keys, conversation data, tool results. Certificate auto-generated on first run. |
| **Bind address** | `127.0.0.1` (localhost) | Only local connections by default. Set `ALFRED_HOST=0.0.0.0` or `--host 0.0.0.0` to allow remote access (iOS app, other machines). |
| **API key** | Required | Bearer token on all endpoints. Timing-safe comparison (`hmac.compare_digest`). |
| **IP allowlist** | `127.0.0.1`, `::1` | Second layer — even with a valid key, connections from non-allowed IPs are rejected (403). |
| **Audit log** | Always on | Every tool call, auth attempt, and response logged to JSONL. |

```bash
# Default: localhost + HTTPS (most secure)
python3 agent.py

# Allow remote connections (e.g. for iOS app on same network)
python3 agent.py --host 0.0.0.0

# Disable TLS for local development
python3 agent.py --no-tls

# Combine: remote access without TLS (least secure, LAN only)
python3 agent.py --host 0.0.0.0 --no-tls
```

> **Note:** The self-signed certificate will trigger browser/client warnings. For the iOS app, configure the client to trust the certificate or use `--no-tls` on a trusted local network. The `certs/` directory is gitignored — each installation generates its own certificate.

---

## Safety Layer

### Destructive Action Gate

Tools that modify the filesystem require explicit `[y/N]` confirmation before execution. In non-interactive mode (piped stdin), destructive actions are auto-denied.

### Path Validation

All file path arguments are resolved and checked against an allowed-roots list. Attempts to access paths outside allowed directories are blocked at the code level, regardless of what the model requests.

### Loop Detection

- **Hard cap**: 25 consecutive tool calls per user message
- **Repeat detection**: if the same tool is called with identical arguments 3 times in a row, the loop is broken

### Prompt Injection Defense

Two layers:
1. **System prompt** — instructs the model that tool results are data, never instructions
2. **Code-level enforcement** — the Python agent intercepts destructive calls regardless of model intent

### Result Truncation

Tool results are capped at 10,000 characters to prevent context window overflow.

---

## Logging

### Audit Log (per-session)

Every session writes a JSONL log to `logs/session_<timestamp>.jsonl` containing tool calls, confirmations, blocked actions, and assistant responses.

### Conversation Log (persistent)

`logs/conversation.log` is a human-readable, append-only log across all sessions. CLI messages appear as `[user]`, MCP messages appear as `[user via mcp]`.

---

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

### MCP Server Tests (8 tests)

```bash
python3 tests/test_mcp_server.py
python3 tests/test_mcp_server.py -v
```

Covers: IP auth, API key auth, SSE connectivity, query param auth, 401/403/404 responses.

### iOS Simulator Tests

Send real prompts to Alfred and inject responses into the iOS simulator. Requires a booted simulator with AlfredChat installed.

```bash
# Run all simulator tests
python3 tests/sim_tests.py

# Run specific tests by ID
python3 tests/sim_tests.py 1 7 18
```

### iOS Simulator Demo Recording

Record a video of the full test suite running in the simulator:

```bash
bash tests/record_demo.sh
# Output: /tmp/sim_tests.mp4
```

### Swift Unit Tests (29 tests)

```bash
cd ios/AlfredChatTests
swift test
```

All 29 tests pass in under 2 seconds.

---

## Tech Stack

| Component | Technology |
|---|---|
| LLM backend | [Ollama](https://ollama.com) |
| Default model | `qwen3-coder:30b` (~18GB, int8) — configurable via `ALFRED_MODEL` |
| LLM client | `ollama` Python SDK |
| HTTP server | `uvicorn` + `starlette` (ASGI) |
| Tool protocol | [Model Context Protocol (MCP)](https://modelcontextprotocol.io) |
| MCP client | `mcp` Python SDK |
| MCP server | `mcp` Python SDK + `uvicorn` (ASGI, SSE) |
| Terminal input | `prompt_toolkit` |
| Terminal output | `rich` |
| iOS client | SwiftUI (iOS 17+) |

---

## Model Notes

- **`qwen3-coder:30b`** is the default — strong tool calling, fits in 32GB+ unified memory
- **`qwen2.5:14b`** is a good alternative for machines with 16GB RAM/VRAM
- **`qwen2.5:3b`** lightweight option for 8-16GB machines — decent quality, manageable on CPU
- **`qwen2.5:0.5b`** minimum viable — runs anywhere but limited reasoning ability
- **`qwen2.5:72b`** for maximum quality on 64GB+ machines
- Change the model via `ALFRED_MODEL` env var, `--model` CLI flag, or edit `.env`
- First `/chat` request after a cold start will take 20+ seconds while Ollama loads the model into memory
- CPU-only inference adds significant latency — expect minutes per response with tool-heavy system prompts on models 3b+
- The XML tool call fallback handles models that occasionally emit raw XML instead of using the structured tool calling API

---

## Project Structure

```
aishell/
+-- agent.py              # Main agent — CLI, REST server, MCP client + SSE server, agent loop, safety
+-- alfred_tui.py         # Standalone TUI REST client (no local LLM needed)
+-- requirements.txt      # Python dependencies
+-- .env.example          # Environment variable template
+-- logs/                 # Session audit logs (JSONL) + persistent conversation.log
+-- tests/
|   +-- test_runner.py    # Python integration test suite (19 tests)
|   +-- test_mcp_server.py # MCP server auth + SSE test suite (8 tests)
|   +-- sim_tests.py      # iOS simulator test suite — real Alfred responses in the app
|   +-- record_demo.sh    # Records a video of the simulator test suite
|   +-- last_results.json # Most recent test results
+-- ios/
|   +-- AlfredChat/       # SwiftUI app source + Xcode project
|   |   +-- AlfredChat/   # Swift source files + Assets.xcassets (app icon)
|   |   +-- gen_project.py  # Xcode project generator
|   +-- AlfredChatTests/  # Swift Package Manager unit tests (29 tests)
+-- .alfred_history       # CLI command history
+-- README.md
```

---

## License

Source available — free for personal and non-commercial use. Commercial use requires a paid license. See [LICENSE](LICENSE) for details.
