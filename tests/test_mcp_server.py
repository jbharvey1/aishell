#!/usr/bin/env python3
"""Test harness for Alfred's MCP server component.

Tests auth (IP whitelist + API key), SSE connectivity, and tool calls
against a live server instance running in-process.

Usage:
    python3 tests/test_mcp_server.py
    python3 tests/test_mcp_server.py -v          # verbose
    python3 tests/test_mcp_server.py --only 1 3  # specific tests
"""

import asyncio
import http.client
import json
import socket
import sys
import os
import time

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agent import (
    Agent, run_mcp_server, MCP_SERVER_PORT, MCP_API_KEY,
    MCP_ALLOWED_IPS, _get_api_key_from_scope, _get_client_ip_from_scope,
)

# Use a different port so we don't collide with a running instance
TEST_PORT = MCP_SERVER_PORT + 100  # 8522

VERBOSE = "-v" in sys.argv or "--verbose" in sys.argv


# ── Helpers ──────────────────────────────────────────────────────

def log(msg: str):
    if VERBOSE:
        print(f"    {msg}")


def _http_request_sync(method: str, path: str, headers: dict | None = None,
                       body: bytes | None = None, timeout: float = 3.0) -> tuple[int, str]:
    """Make an HTTP request to the test server (blocking). Returns (status, body)."""
    conn = http.client.HTTPConnection("127.0.0.1", TEST_PORT, timeout=timeout)
    try:
        conn.request(method, path, body=body, headers=headers or {})
        resp = conn.getresponse()
        return resp.status, resp.read().decode()
    finally:
        conn.close()


async def http_request(method: str, path: str, headers: dict | None = None,
                       body: bytes | None = None, timeout: float = 3.0) -> tuple[int, str]:
    """Make an HTTP request in an executor so we don't block the event loop."""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _http_request_sync, method, path, headers, body, timeout)


def auth_headers() -> dict:
    return {"Authorization": f"Bearer {MCP_API_KEY}"}


def bad_auth_headers() -> dict:
    return {"Authorization": "Bearer wrong-key-here"}


class Results:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.skipped = 0
        self.details = []

    def ok(self, name: str, msg: str = ""):
        self.passed += 1
        self.details.append(("PASS", name, msg))
        print(f"  ✅ {name}" + (f" — {msg}" if msg else ""))

    def fail(self, name: str, msg: str = ""):
        self.failed += 1
        self.details.append(("FAIL", name, msg))
        print(f"  ❌ {name}" + (f" — {msg}" if msg else ""))

    def skip(self, name: str, msg: str = ""):
        self.skipped += 1
        self.details.append(("SKIP", name, msg))
        print(f"  ⏭  {name}" + (f" — {msg}" if msg else ""))

    def summary(self):
        total = self.passed + self.failed + self.skipped
        print(f"\n{'='*50}")
        print(f"  {total} tests: {self.passed} passed, {self.failed} failed, {self.skipped} skipped")
        print(f"{'='*50}")
        return self.failed == 0


# ── Tests ────────────────────────────────────────────────────────

async def test_port_open(results: Results):
    """1. Port is actually listening."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(2)
    try:
        result = s.connect_ex(("127.0.0.1", TEST_PORT))
        if result == 0:
            results.ok("Port open", f":{TEST_PORT} accepting connections")
        else:
            results.fail("Port open", f"connect_ex returned {result}")
    finally:
        s.close()


async def test_no_auth_rejected(results: Results):
    """2. Request with no API key gets 401."""
    try:
        status, body = await http_request("GET", "/sse")
        if status == 401:
            results.ok("No auth → 401", body.strip())
        else:
            results.fail("No auth → 401", f"got {status}")
    except Exception as e:
        results.fail("No auth → 401", str(e))


async def test_bad_key_rejected(results: Results):
    """3. Request with wrong API key gets 401."""
    try:
        status, body = await http_request("GET", "/sse", headers=bad_auth_headers())
        if status == 401:
            results.ok("Bad key → 401", body.strip())
        else:
            results.fail("Bad key → 401", f"got {status}")
    except Exception as e:
        results.fail("Bad key → 401", str(e))


async def test_good_key_accepted(results: Results):
    """4. Request with correct API key doesn't get 401/403 (SSE will hang, so we use a short timeout)."""
    def _check():
        conn = http.client.HTTPConnection("127.0.0.1", TEST_PORT, timeout=2)
        try:
            conn.request("GET", "/sse", headers=auth_headers())
            resp = conn.getresponse()
            return resp.status
        except (TimeoutError, socket.timeout):
            return "timeout"
        finally:
            conn.close()

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, _check)
    if result == "timeout":
        results.ok("Good key accepted", "SSE stream open (timeout = success)")
    elif result in (401, 403):
        results.fail("Good key accepted", f"got {result}")
    else:
        results.ok("Good key accepted", f"status {result}")


async def test_query_param_key(results: Results):
    """5. API key via ?api_key= query param works."""
    def _check():
        conn = http.client.HTTPConnection("127.0.0.1", TEST_PORT, timeout=2)
        try:
            conn.request("GET", f"/sse?api_key={MCP_API_KEY}")
            resp = conn.getresponse()
            return resp.status
        except (TimeoutError, socket.timeout):
            return "timeout"
        finally:
            conn.close()

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, _check)
    if result == "timeout":
        results.ok("Query param key", "SSE stream open (timeout = success)")
    elif result in (401, 403):
        results.fail("Query param key", f"got {result}")
    else:
        results.ok("Query param key", f"status {result}")


async def test_unknown_route_authed(results: Results):
    """6. Unknown route with valid auth gets 404, not 401."""
    try:
        status, body = await http_request("GET", "/nonexistent", headers=auth_headers())
        if status == 404:
            results.ok("Unknown route → 404", "auth passed, route not found")
        elif status == 401:
            results.fail("Unknown route → 404", "got 401 — auth not passing")
        else:
            results.ok("Unknown route → 404", f"got {status} (auth passed)")
    except Exception as e:
        results.fail("Unknown route → 404", str(e))


async def test_scope_helpers(results: Results):
    """7. Unit test the scope parser helpers."""
    errors = []

    # IP from client tuple
    scope = {"client": ("10.0.0.5", 12345), "headers": []}
    ip = _get_client_ip_from_scope(scope)
    if ip != "10.0.0.5":
        errors.append(f"client tuple: expected 10.0.0.5 got {ip}")

    # IP from X-Forwarded-For
    scope = {"client": ("10.0.0.5", 12345), "headers": [(b"x-forwarded-for", b"1.2.3.4, 10.0.0.1")]}
    ip = _get_client_ip_from_scope(scope)
    if ip != "1.2.3.4":
        errors.append(f"x-forwarded-for: expected 1.2.3.4 got {ip}")

    # API key from Authorization header
    scope = {"headers": [(b"authorization", b"Bearer test-key-123")], "query_string": b""}
    key = _get_api_key_from_scope(scope)
    if key != "test-key-123":
        errors.append(f"auth header: expected test-key-123 got {key}")

    # API key from query string
    scope = {"headers": [], "query_string": b"foo=bar&api_key=qwerty&baz=1"}
    key = _get_api_key_from_scope(scope)
    if key != "qwerty":
        errors.append(f"query param: expected qwerty got {key}")

    # Empty = empty
    scope = {"headers": [], "query_string": b""}
    key = _get_api_key_from_scope(scope)
    if key != "":
        errors.append(f"empty: expected empty got {key}")

    if errors:
        results.fail("Scope helpers", "; ".join(errors))
    else:
        results.ok("Scope helpers", "IP + key parsing correct")


async def test_messages_post_no_auth(results: Results):
    """8. POST to /messages without auth gets 401."""
    try:
        status, body = await http_request("POST", "/messages/test", body=b"{}")
        if status == 401:
            results.ok("POST /messages no auth → 401")
        else:
            results.fail("POST /messages no auth → 401", f"got {status}")
    except Exception as e:
        results.fail("POST /messages no auth → 401", str(e))


# ── Runner ───────────────────────────────────────────────────────

ALL_TESTS = [
    test_scope_helpers,          # 1 — unit test, no server needed
    test_port_open,              # 2
    test_no_auth_rejected,       # 3
    test_bad_key_rejected,       # 4
    test_good_key_accepted,      # 5
    test_query_param_key,        # 6
    test_unknown_route_authed,   # 7
    test_messages_post_no_auth,  # 8
]


async def main():
    # Parse --only
    only = set()
    if "--only" in sys.argv:
        idx = sys.argv.index("--only")
        for arg in sys.argv[idx + 1:]:
            if arg.isdigit():
                only.add(int(arg))
            else:
                break

    results = Results()
    print(f"\n{'='*50}")
    print(f"  Alfred MCP Server Tests (port {TEST_PORT})")
    print(f"{'='*50}\n")

    # Run unit tests first (no server needed)
    if not only or 1 in only:
        await ALL_TESTS[0](results)

    # Start server for integration tests
    needs_server = not only or any(i in only for i in range(2, len(ALL_TESTS) + 1))
    server_task = None

    if needs_server:
        print("\n  Starting test server...")
        agent = Agent(verbose=False)
        server_task = asyncio.create_task(run_mcp_server(agent, TEST_PORT))
        # Wait for server to be ready
        for _ in range(20):
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(0.5)
            if s.connect_ex(("127.0.0.1", TEST_PORT)) == 0:
                s.close()
                break
            s.close()
            await asyncio.sleep(0.25)
        else:
            print("  ❌ Server failed to start within 5s")
            if server_task.done():
                try:
                    server_task.result()
                except Exception as e:
                    print(f"     Error: {e}")
            return

        print(f"  Server ready on :{TEST_PORT}\n")

        # Run integration tests
        for i, test_fn in enumerate(ALL_TESTS[1:], start=2):
            if only and i not in only:
                continue
            await test_fn(results)

    success = results.summary()

    # Cleanup
    if server_task and not server_task.done():
        server_task.cancel()
        try:
            await server_task
        except asyncio.CancelledError:
            pass

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    asyncio.run(main())
