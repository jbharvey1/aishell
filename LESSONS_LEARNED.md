# Lessons Learned — AlfredChat XCUITest E2E

**Date:** 2026-03-25

## Critical Bugs Found & Fixed

### 1. ollama.chat() blocks the asyncio event loop
`agent.py` called `ollama.chat()` synchronously inside an `async def chat()` method. Since uvicorn runs on the same event loop, this blocked ALL HTTP handling (including `/health`) while the LLM was generating. After one chat request, the entire server became unresponsive.

**Fix:** Wrapped in `run_in_executor`:
```python
response = await asyncio.get_event_loop().run_in_executor(None, lambda: ollama.chat(...))
```

### 2. agent.py exits immediately under nohup
The TUI uses `prompt_toolkit` (interactive) or `input()` (piped). Under `nohup`, stdin gets EOF immediately, triggering the `EOFError` handler → "Goodbye, sir." → exit. The MCP server dies with it.

**Fix:** Keep stdin open with `tail -f /dev/null |`:
```bash
nohup bash -c "tail -f /dev/null | .venv/bin/python3 agent.py" > /tmp/alfred.log 2>&1 &
```

### 3. ollama 30b model can hang
`qwen3-coder:30b` occasionally becomes completely unresponsive — the ollama API accepts connections but never returns a response. Requires full ollama restart (`pkill ollama` + relaunch).

## Architecture Discoveries

### iOS project layout
- **Actual path:** `~/ios-mcp-app/AlfredChat/` (NOT `~/aishell/ios/AlfredChat/` as documented)
- `gen_project.py` lives in `AlfredChat/AlfredChat/` but must be run from `AlfredChat/` (the parent) because the pbxproj group path `AlfredChat` is relative to the xcodeproj location

### XCUITest config injection
No app code changes needed for test configuration. `@AppStorage` properties can be overridden via launch arguments using the `-key value` NSArgumentDomain pattern:
```swift
app.launchArguments = ["-alfred_host", "192.168.1.40", "-alfred_apikey", "..."]
```

### Code signing over SSH
`xcodebuild` code signing fails over SSH with `errSecInternalComponent` because the macOS Keychain is locked. `security unlock-keychain` requires the login password. Device builds and `git push` must be done from a local Mac terminal.

### Python venv
The Mac had no venv for aishell. System Python (homebrew 3.14) blocks `pip install` with PEP 668. Created `~/aishell/.venv/` with all requirements installed.

## Test Results

All 5 XCUITest E2E tests pass:
| Test | Time | What it validates |
|------|------|-------------------|
| test01_TimeQuery | 20.6s | Basic chat round-trip |
| test02_FileList | 32.1s | MCP filesystem tool usage |
| test03_PathBoundary | 58.7s | Security: path traversal blocked |
| test04_DestructiveGate | 14.3s | Safety: write operations gated |
| test05_ErrorHandling | 59.0s | Graceful error for missing files |
