#!/usr/bin/env python3
"""Restart Zen gracefully and restore tabs via WebDriver BiDi.

Zen forces browser.sessionstore.* off and never hot-reloads chrome CSS,
so the only way to pick up a new Noctalia theme is a process restart.
This script snapshots the current tab URLs, restarts zen, then re-opens
them so the restart is transparent to the user.
"""
import json
import subprocess
import sys
import time

try:
    import websocket
except ImportError:
    print("[zen-restart] websocket-client not available", file=sys.stderr)
    sys.exit(2)

PORT = 9222
WS_URL = f"ws://127.0.0.1:{PORT}/session"


def bidi(ws, mid, method, params=None, timeout=8):
    ws.settimeout(timeout)
    ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
    while True:
        msg = json.loads(ws.recv())
        if msg.get("id") == mid:
            return msg


def connect():
    return websocket.create_connection(WS_URL, timeout=8, suppress_origin=True)


def main():
    tabs = []
    # 1. snapshot current tabs (best effort)
    try:
        ws = connect()
        bidi(ws, 1, "session.new", {"capabilities": {}})
        r = bidi(ws, 2, "browsingContext.getTree", {})
        for c in r.get("result", {}).get("contexts", []):
            u = c.get("url", "")
            if u and not u.startswith("about:") and not u.startswith("zen:"):
                tabs.append(u)
        bidi(ws, 3, "session.end", {})
        ws.close()
    except Exception as e:
        print(f"[zen-restart] snapshot failed: {e}", file=sys.stderr)
        # no debug port -> zen was started manually; do not restart and
        # lose its tabs, leave the restart to the user
        sys.exit(2)
    print(f"[zen-restart] tabs to restore: {tabs}")

    # 2. restart zen
    subprocess.run(["pkill", "-x", "zen-bin"], check=False)
    time.sleep(3)
    subprocess.Popen(
        ["zen-browser", f"--remote-debugging-port={PORT}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # 3. wait for the remote agent to come up
    ws = None
    for _ in range(25):
        time.sleep(2)
        try:
            probe = connect()
            r = bidi(probe, 1, "session.new", {"capabilities": {}})
            if r.get("result"):
                ws = probe
                break
            probe.close()
        except Exception:
            continue
    if ws is None:
        print("[zen-restart] zen did not come up in time", file=sys.stderr)
        sys.exit(1)

    # 4. restore tabs
    r = bidi(ws, 2, "browsingContext.getTree", {})
    first = r.get("result", {}).get("contexts", [{}])[0].get("context")
    if first and tabs:
        bidi(ws, 3, "browsingContext.navigate",
             {"context": first, "url": tabs[0], "wait": "none"})
        for u in tabs[1:]:
            r = bidi(ws, 4, "browsingContext.create", {"type": "tab"})
            c = r.get("result", {}).get("context")
            if c:
                bidi(ws, 5, "browsingContext.navigate",
                     {"context": c, "url": u, "wait": "none"})
    try:
        bidi(ws, 9, "session.end", {})
    except Exception:
        pass
    ws.close()
    print(f"[zen-restart] restored {len(tabs)} tabs")


if __name__ == "__main__":
    main()
