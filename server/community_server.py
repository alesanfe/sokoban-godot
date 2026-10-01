#!/usr/bin/env python3
"""Community backend for Sokoban Mutante — self-hosted, stdlib only.

Run:  python server/community_server.py [port]   (default 8765)
Data: server/community_db.json (atomic writes, JSON array store)

Endpoints (all JSON; CORS open so the web export can call it):
  GET  /api/feed                       -> {"entries": [...]}
  POST /api/publish  {title, author, data, rules, par?}  -> {"id"}
  POST /api/like     {id}
  POST /api/play     {id}
  POST /api/clear    {id}
  POST /api/remove   {id, token}  — token returned by /api/publish

Auth: publish issues a per-entry token; remove requires it. The token
is never exposed by /api/feed (stripped on read). Name-matching alone
let anyone retire a level; the token is the actual auth boundary for
self-hosted instances shared with strangers on a LAN.

The heavy validation (level parse, playtest gate) stays client-side;
the server enforces shape/size limits so a malformed payload can't
poison the feed.
"""

import json
import os
import secrets
import sys
import tempfile
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

_lock = threading.Lock()  # read-modify-write es atómico entre workers

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(BASE, "community_db.json")

MAX_ENTRY_BYTES = 64 * 1024          # a level payload is a few KB
MAX_ENTRIES = 5000
MAX_TITLE = 120
MAX_AUTHOR = 40


def _load() -> list:
    if not os.path.exists(DB):
        return []
    try:
        with open(DB, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def _save(entries: list) -> None:
    fd, tmp = tempfile.mkstemp(dir=BASE, suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False)
    os.replace(tmp, DB)


def _sanitize(e: dict) -> dict | None:
    """Strict entry shape — anything else is rejected.
    LevelData.to_dict() emits {board, over, rules, …} — 'board' is the
    newline-joined grid string."""
    if not (isinstance(e.get("data"), dict)
            and isinstance(e["data"].get("board"), str)):
        return None
    if not isinstance(e.get("title"), str) or not 0 < len(e["title"]) <= MAX_TITLE:
        return None
    if not isinstance(e.get("author"), str) or not 0 < len(e["author"]) <= MAX_AUTHOR:
        return None
    rules = e.get("rules", [])
    if not isinstance(rules, list) or len(rules) > 8:
        return None
    return {
        "id": uuid.uuid4().hex[:12],
        "token": secrets.token_hex(16),      # auth de borrado — nunca sale por /feed
        "title": e["title"], "author": e["author"],
        "data": e["data"],
        "rules": [str(r)[:24] for r in rules],
        "difficulty": int(e.get("difficulty", 1) or 1),
        "par": int(e.get("par", 0) or 0),
        "ts": int(time.time()),
        "likes": 0, "plays": 0, "clears": 0,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "SokobanCommunity/1.0"

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, code: int, obj) -> None:
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:
        if self.path.rstrip("/") == "/api/feed":
            # el token es el secreto de borrado: no lo filtra el feed
            feed = [{k: v for k, v in e.items() if k != "token"}
                    for e in _load()]
            self._json(200, {"entries": feed})
        elif self.path.rstrip("/") == "/api/health":
            self._json(200, {"ok": True})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self) -> None:
        path = self.path.rstrip("/")
        try:
            n = int(self.headers.get("Content-Length", 0))
        except ValueError:
            n = 0
        if not 0 < n <= MAX_ENTRY_BYTES + 4096:
            self._json(400, {"error": "bad body"})
            return
        try:
            body = json.loads(self.rfile.read(n))
        except json.JSONDecodeError:
            self._json(400, {"error": "bad json"})
            return
        if not isinstance(body, dict):
            self._json(400, {"error": "bad json"})
            return

        # lock alrededor de TODO el read-modify-write: sin él dos
        # likes concurrentes podían perder uno de los incrementos
        with _lock:
            entries = _load()
            if path == "/api/publish":
                entry = _sanitize(body)
                if entry is None:
                    self._json(422, {"error": "invalid entry"})
                    return
                entries.insert(0, entry)
                _save(entries[:MAX_ENTRIES])
                self._json(201, {"id": entry["id"], "token": entry["token"]})
                return

            eid = str(body.get("id", ""))
            entry = next((e for e in entries if e.get("id") == eid), None)
            if entry is None:
                self._json(404, {"error": "unknown id"})
                return
            if path == "/api/like":
                entry["likes"] += 1
            elif path == "/api/play":
                entry["plays"] += 1
            elif path == "/api/clear":
                entry["clears"] += 1
            elif path == "/api/remove":
                if not secrets.compare_digest(
                        str(entry.get("token", "")),
                        str(body.get("token", ""))):
                    self._json(403, {"error": "not the author"})
                    return
                entries.remove(entry)
                _save(entries)
                self._json(200, {"removed": eid})
                return
            else:
                self._json(404, {"error": "not found"})
                return
            _save(entries)
            self._json(200, {"ok": True})

    def log_message(self, fmt, *args) -> None:
        sys.stderr.write("[%s] %s\n" % (time.strftime("%H:%M:%S"), fmt % args))


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print(f"Sokoban community server on http://0.0.0.0:{port}")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
