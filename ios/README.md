# AlfredChat iOS

Native iOS/iPadOS chat client for the Alfred AI assistant.

## Architecture

- **Transport**: Simple REST — `GET /health` (instant ping, no LLM) + `POST /chat` (message)
- **No MCP/SSE**: Plain JSON over HTTP for reliability on iOS
- **Auth**: `Authorization: Bearer <key>` on all requests

## Files

| File | Purpose |
|------|---------|
| `AlfredChat/MCPClient.swift` | REST client — health check + chat, separate timeouts |
| `AlfredChat/ContentView.swift` | Chat UI — messages, input bar, status banner |
| `AlfredChat/Models.swift` | `ChatMessage`, `MCPConfig` defaults |
| `AlfredChat/SettingsView.swift` | Host/port/API key settings sheet |
| `AlfredChat/AlfredChatApp.swift` | App entry point |
| `AlfredChat/Info.plist` | ATS local networking, NSLocalNetworkUsageDescription |
| `AlfredChat/gen_project.py` | Generates AlfredChat.xcodeproj/project.pbxproj |

## Building

```bash
cd AlfredChat
python3 gen_project.py     # generates Xcode project
open AlfredChat.xcodeproj  # Cmd+R to build and run
```

## Running Tests

```bash
cd AlfredChatTests && swift test
```

29 tests: error types, models, JSON parsing, HTTP status, URL construction.

## Remote Debugging via SSH

```bash
xcrun simctl spawn booted log stream \
  --predicate 'subsystem == "com.jbharvey.AlfredChat"' --level debug

xcrun simctl io booted screenshot /tmp/snap.png
```

## Alfred Server Requirements

- `GET /health` → `{"status":"ok"}` (instant, no LLM)
- `POST /chat` body `{"message":"..."}` → `{"response":"..."}` (LLM)
- `Authorization: Bearer <key>` required on all requests
