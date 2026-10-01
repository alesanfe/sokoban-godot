#!/usr/bin/env python3
"""Community backend for Sokoban Mutante — self-hosted, stdlib only.

Run:  python server/community_server.py [port]   (default 8765)
Data: server/community.db (SQLite, WAL — safe under ThreadingHTTPServer;
      migrates an existing community_db.json on first start)

Endpoints (all JSON; CORS open so the web export can call it):
  GET  /api/feed                       -> {"entries": [...]}
  POST /api/publish  {title, author, data, rules, par?}  -> {"id", "token"}
  POST /api/like     {id}
  POST /api/play     {id}
  POST /api/clear    {id}
  POST /api/remove   {id, token}  — token returned by /api/publish

Auth: publish issues a per-entry token; remove requires it. The token
is never exposed by /api/feed (not selected). Name-matching alone let
anyone retire a level; the token is the actual auth boundary for
self-hosted instances shared with strangers on a LAN.

CORS is `*`: the feed is PUBLIC read-only data and auth travels in the
POST body (no cookies/credentials), so an open policy leaks nothing.
Error payloads carry a stable "code" for clients, plus "error" text.

Why SQLite and not the JSON file it replaced: counters are atomic SQL
updates (no read-modify-write race even if the lock were wrong), the
store survives partial writes, and feed queries use an index instead
of loading the whole catalogue on every request.
"""

import json
import os
import secrets
import sqlite3
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

_rate_lock = threading.Lock()
_rate: dict[str, list] = {}          # ip -> timestamps de mutaciones

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(BASE, "community.db")
LEGACY_JSON = os.path.join(BASE, "community_db.json")

RATE_WINDOW = 60.0                   # s
RATE_MAX = 30                        # POST por ventana e IP — el juego
# legítimo hace ≤ ~5/min (publish+like+clear); el límite corta floods

MAX_ENTRY_BYTES = 64 * 1024          # a level payload is a few KB
MAX_ENTRIES = 5000
MAX_TITLE = 120
MAX_AUTHOR = 40

_COLS = ("id", "title", "author", "data", "rules", "difficulty",
         "par", "ts", "likes", "plays", "clears")   # token NUNCA aquí


def _conn() -> sqlite3.Connection:
    """Connection per operation — threads share nothing."""
    c = sqlite3.connect(DB, timeout=10)
    c.execute("PRAGMA journal_mode=WAL")
    return c


def _init_db() -> None:
    with _conn() as c:
        c.execute("""CREATE TABLE IF NOT EXISTS entries(
            id TEXT PRIMARY KEY, token TEXT NOT NULL,
            title TEXT NOT NULL, author TEXT NOT NULL,
            data TEXT NOT NULL, rules TEXT NOT NULL,
            difficulty INTEGER, par INTEGER, ts INTEGER,
            likes INTEGER DEFAULT 0, plays INTEGER DEFAULT 0,
            clears INTEGER DEFAULT 0)""")
        c.execute("CREATE INDEX IF NOT EXISTS idx_entries_ts"
                  " ON entries(ts DESC)")
        # migración desde el store JSON anterior (si existe): importa
        # una vez y renombra el fichero para no repetir
        if os.path.exists(LEGACY_JSON):
            try:
                with open(LEGACY_JSON, "r", encoding="utf-8") as f:
                    old = json.load(f)
            except (OSError, json.JSONDecodeError):
                old = []
            for e in old if isinstance(old, list) else []:
                if not isinstance(e, dict) or not e.get("id"):
                    continue
                c.execute("""INSERT OR IGNORE INTO entries(
                    id,token,title,author,data,rules,difficulty,par,ts,
                    likes,plays,clears) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (str(e["id"]),
                     str(e.get("token") or secrets.token_hex(16)),
                     str(e.get("title", ""))[:MAX_TITLE],
                     str(e.get("author", ""))[:MAX_AUTHOR],
                     json.dumps(e.get("data", {}), ensure_ascii=False),
                     json.dumps(e.get("rules", []), ensure_ascii=False),
                     int(e.get("difficulty", 1) or 1),
                     int(e.get("par", 0) or 0),
                     int(e.get("ts", 0)),
                     int(e.get("likes", 0)), int(e.get("plays", 0)),
                     int(e.get("clears", 0))))
            os.replace(LEGACY_JSON, LEGACY_JSON + ".migrated")


def _feed() -> list:
    """Feed ordenado por ts desc, acotado — el token NO se selecciona."""
    with _conn() as c:
        rows = c.execute(
            "SELECT id,title,author,data,rules,difficulty,par,ts,"
            "likes,plays,clears FROM entries ORDER BY ts DESC"
            " LIMIT ?", (MAX_ENTRIES,)).fetchall()
    out = []
    for r in rows:
        e = dict(zip(_COLS, r))
        for k in ("data", "rules"):
            try:
                e[k] = json.loads(e[k])
            except json.JSONDecodeError:
                e[k] = {} if k == "data" else []
        out.append(e)
    return out


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
        "data": json.dumps(e["data"], ensure_ascii=False),
        "rules": json.dumps([str(r)[:24] for r in rules],
                          ensure_ascii=False),
        "difficulty": int(e.get("difficulty", 1) or 1),
        "par": int(e.get("par", 0) or 0),
        "ts": int(time.time()),
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "SokobanCommunity/2.0"

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, code: int, obj, err_code: str = "") -> None:
        # errores = {"error": texto, "code": estable} — el cliente
        # puede reaccionar sin parsear strings variables
        if code >= 400 and isinstance(obj, dict):
            obj = {"code": err_code or "error", **obj}
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
            self._json(200, {"entries": _feed()})
        elif self.path.rstrip("/") == "/api/health":
            self._json(200, {"ok": True})
        else:
            self._json(404, {"error": "not found"}, "not_found")

    def do_POST(self) -> None:
        path = self.path.rstrip("/")
        # rate-limit por IP: ventana deslizante de mutaciones — sin él
        # un script podía inflar contadores o machacar la DB
        with _rate_lock:
            now = time.time()
            ws = _rate.setdefault(self.client_address[0], [])
            ws[:] = [t for t in ws if now - t < RATE_WINDOW]
            if len(ws) >= RATE_MAX:
                self._json(429, {"error": "rate limited"},
                           "rate_limited")
                return
            ws.append(now)
        try:
            n = int(self.headers.get("Content-Length", 0))
        except ValueError:
            n = 0
        if not 0 < n <= MAX_ENTRY_BYTES + 4096:
            self._json(400, {"error": "bad body"}, "bad_body")
            return
        try:
            body = json.loads(self.rfile.read(n))
        except json.JSONDecodeError:
            self._json(400, {"error": "bad json"}, "bad_json")
            return
        if not isinstance(body, dict):
            self._json(400, {"error": "bad json"}, "bad_json")
            return

        if path == "/api/publish":
            entry = _sanitize(body)
            if entry is None:
                self._json(422, {"error": "invalid entry"},
                           "invalid_entry")
                return
            with _conn() as c:
                c.execute("INSERT INTO entries(" + ",".join(_COLS) +
                          ",token) VALUES(?,?,?,?,?,?,?,?,0,0,0,?)",
                          (entry["id"], entry["title"], entry["author"],
                           entry["data"], entry["rules"],
                           entry["difficulty"], entry["par"],
                           entry["ts"], entry["token"]))
                # cap de catálogo: conserva los MAX_ENTRIES más nuevos
                c.execute("""DELETE FROM entries WHERE id NOT IN (
                    SELECT id FROM entries ORDER BY ts DESC LIMIT ?)""",
                    (MAX_ENTRIES,))
            self._json(201, {"id": entry["id"], "token": entry["token"]})
            return

        eid = str(body.get("id", ""))
        if path == "/api/remove":
            with _conn() as c:
                row = c.execute("SELECT token FROM entries WHERE id=?",
                                (eid,)).fetchone()
                if row is None:
                    self._json(404, {"error": "unknown id"},
                               "unknown_id")
                    return
                if not secrets.compare_digest(
                        row[0], str(body.get("token", ""))):
                    self._json(403, {"error": "not the author"},
                               "forbidden")
                    return
                c.execute("DELETE FROM entries WHERE id=?", (eid,))
            self._json(200, {"removed": eid})
            return

        # contadores: UPDATE atómico — sin race aunque los hilos
        # intercalen (la causa del antiguo lock RMW desaparece en SQL)
        if path in ("/api/like", "/api/play", "/api/clear"):
            field = path.rsplit("/", 1)[1]
            with _conn() as c:
                cur = c.execute(
                    f"UPDATE entries SET {field}s = {field}s + 1"
                    " WHERE id = ?", (eid,))
            if cur.rowcount == 0:
                self._json(404, {"error": "unknown id"}, "unknown_id")
                return
            self._json(200, {"ok": True})
            return

        self._json(404, {"error": "not found"}, "not_found")

    def log_message(self, fmt, *args) -> None:
        sys.stderr.write("[%s] %s\n" % (time.strftime("%H:%M:%S"), fmt % args))


if __name__ == "__main__":
    _init_db()
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print(f"Sokoban community server on http://0.0.0.0:{port}")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
