#!/usr/bin/env python3
"""Alfred TUI — terminal client for the Alfred REST API.

Connects to a running Alfred instance over HTTP.
Same look and feel as agent.py, no local LLM or MCP required.

Usage:
    python3 alfred_tui.py
    python3 alfred_tui.py --host 192.168.1.40 --port 8422
    python3 alfred_tui.py --quiet

Config (env / .env):
    ALFRED_API_KEY   bearer token
    ALFRED_HOST      server host   (default: 127.0.0.1)
    ALFRED_PORT      server port   (default: 8422)
"""

import asyncio
import os
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

try:
    from dotenv import load_dotenv
    _here = os.path.dirname(os.path.abspath(__file__))
    load_dotenv(os.path.join(_here, "alfred_tui.env"))
    load_dotenv()  # also load .env from CWD if present
except ImportError:
    pass

import httpx
from prompt_toolkit import PromptSession
from prompt_toolkit.history import FileHistory
from prompt_toolkit.auto_suggest import AutoSuggestFromHistory
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.styles import Style as PTStyle
from rich.console import Console
from rich.live import Live
from rich.markdown import Markdown
from rich.panel import Panel
from rich.spinner import Spinner
from rich.text import Text
from rich.theme import Theme

# ── Terminal setup ───────────────────────────────────────────────

THEME = Theme({
    "alfred": "bold cyan",
    "tool":   "dim yellow",
    "result": "dim",
    "safety": "bold red",
    "info":   "dim cyan",
})

console = Console(theme=THEME, force_terminal=True, highlight=False)

HISTORY_FILE = os.path.expanduser("~/.alfred_tui_history")

SLASH_COMMANDS = ["/verbose", "/quiet", "/reconnect", "/help", "/clear"]

prompt_style = PTStyle.from_dict({
    "prompt": "#a78bfa bold",
})

# ── Config ───────────────────────────────────────────────────────

def _parse_args():
    host = os.environ.get("ALFRED_HOST", "127.0.0.1")
    port = int(os.environ.get("ALFRED_PORT", "8422"))
    key  = os.environ.get("ALFRED_API_KEY", "change-me")
    verbose = "--quiet" not in sys.argv and "-q" not in sys.argv

    if "--host" in sys.argv:
        host = sys.argv[sys.argv.index("--host") + 1]
    if "--port" in sys.argv:
        port = int(sys.argv[sys.argv.index("--port") + 1])
    if "--key" in sys.argv:
        key = sys.argv[sys.argv.index("--key") + 1]

    return host, port, key, verbose


# ── HTTP client ──────────────────────────────────────────────────

class AlfredClient:
    def __init__(self, host: str, port: int, key: str):
        self.base = f"http://{host}:{port}"
        self.headers = {"Authorization": f"Bearer {key}"}

    async def health(self) -> bool:
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.get(f"{self.base}/health", headers=self.headers)
                return r.status_code == 200
        except Exception:
            return False

    async def chat(self, message: str) -> str:
        async with httpx.AsyncClient(timeout=120) as c:
            r = await c.post(
                f"{self.base}/chat",
                headers={**self.headers, "Content-Type": "application/json"},
                json={"message": message},
            )
            if r.status_code == 401:
                raise PermissionError("Invalid API key")
            if r.status_code != 200:
                raise RuntimeError(f"HTTP {r.status_code}: {r.text[:200]}")
            data = r.json()
            return data.get("response", "")


# ── Rendering ────────────────────────────────────────────────────

def render_alfred(text: str):
    console.print()
    console.print(Panel(
        Markdown(text),
        title="[bold cyan]Alfred[/bold cyan]",
        border_style="cyan",
        padding=(1, 2),
    ))
    console.print()


async def thinking_and_chat(client: AlfredClient, message: str) -> str:
    """Send chat request while showing a spinner."""
    result = None
    error  = None

    async def _do_chat():
        nonlocal result, error
        try:
            result = await client.chat(message)
        except Exception as e:
            error = e

    task = asyncio.create_task(_do_chat())

    with Live(
        Spinner("dots", text=Text(" Alfred is thinking...", style="dim cyan")),
        console=console,
        refresh_per_second=12,
        transient=True,
    ):
        await task

    if error:
        raise error
    return result


# ── Help ─────────────────────────────────────────────────────────

HELP_TEXT = """\
[bold cyan]Alfred TUI — Commands[/bold cyan]

[bold]/verbose[/bold]       Show full markdown rendering
[bold]/quiet[/bold]         Plain text output only
[bold]/reconnect[/bold]     Re-check Alfred connection
[bold]/clear[/bold]         Clear screen
[bold]/help[/bold]          Show this help
[bold]quit[/bold] or [bold]exit[/bold]   Exit

[dim]Tips: ↑/↓ arrows for history · tab for command completion[/dim]"""


# ── Main ─────────────────────────────────────────────────────────

async def main():
    host, port, key, verbose = _parse_args()
    client = AlfredClient(host, port, key)

    mode_label = "verbose" if verbose else "quiet"
    console.print(Panel(
        f"[bold cyan]Alfred TUI[/bold cyan] — Remote Terminal Client\n"
        f"[dim]Server: {host}:{port}  |  Mode: {mode_label}[/dim]",
        border_style="cyan",
    ))

    console.print("  Connecting to Alfred...", end=" ")
    if await client.health():
        console.print("[green]✓ connected[/green]\n")
    else:
        console.print("[red]✗ unreachable[/red]")
        console.print(f"  [dim]Is Alfred running at {host}:{port}?[/dim]")
        console.print(f"  [dim]Set ALFRED_HOST / ALFRED_PORT in .env or use --host / --port[/dim]\n")
        sys.exit(1)

    completer = WordCompleter(SLASH_COMMANDS, sentence=True)
    try:
        session = PromptSession(
            history=FileHistory(HISTORY_FILE),
            auto_suggest=AutoSuggestFromHistory(),
            completer=completer,
            complete_while_typing=False,
            style=prompt_style,
        )
    except Exception:
        session = None  # fallback to plain input()

    while True:
        try:
            if session:
                user_input = await asyncio.get_event_loop().run_in_executor(
                    None,
                    lambda: session.prompt(HTML("<prompt>You: </prompt>")).strip()
                )
            else:
                user_input = await asyncio.get_event_loop().run_in_executor(
                    None, lambda: input("You: ").strip()
                )
        except (EOFError, KeyboardInterrupt):
            console.print("\n[cyan]Goodbye, sir.[/cyan]")
            break

        if not user_input:
            continue
        if user_input.lower() in ("quit", "exit"):
            console.print("[cyan]Goodbye, sir.[/cyan]")
            break

        cmd = user_input.lower()

        if cmd == "/verbose":
            verbose = True
            console.print("  [green]✓[/green] Verbose mode.\n")
            continue

        if cmd == "/quiet":
            verbose = False
            console.print("  [green]✓[/green] Quiet mode.\n")
            continue

        if cmd == "/clear":
            console.clear()
            continue

        if cmd == "/help":
            console.print(HELP_TEXT)
            continue

        if cmd == "/reconnect":
            console.print("  Reconnecting...", end=" ")
            if await client.health():
                console.print("[green]✓ connected[/green]\n")
            else:
                console.print("[red]✗ unreachable[/red]\n")
            continue

        try:
            response = await thinking_and_chat(client, user_input)
            if verbose:
                render_alfred(response)
            else:
                console.print(f"\n  {response}\n")
        except PermissionError as e:
            console.print(f"\n  [safety]✗ Auth error:[/safety] {e}\n")
        except Exception as e:
            console.print(f"\n  [safety]✗ Error:[/safety] {e}\n")


if __name__ == "__main__":
    asyncio.run(main())
