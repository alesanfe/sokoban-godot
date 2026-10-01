#!/usr/bin/env python3
"""Community backend for Sokoban Mutante — self-hosted, stdlib only.

Run:    python server/community_server.py [--port N] [--host A] [--db F]
Config: SKM_DB, SKM_MAX_ENTRIES, SKM_RATE_MAX (env fallbacks)
Data:   server/community.db (SQLite, WAL — safe under ThreadingHTTPServer;
        migrates a legacy community_db.json on first start)

Endpoints (all JSON):
  GET  /api/feed?offset=N&limit=M    -> {"entries":[…], "total", "offset", "limit"}
  GET  /api/health                   -> {"ok": true}  (fails if the DB is gone)
  POST /api/publish  {title, author, data, rules, par?}  -> {"id", "token"}
  POST /api/like     {id}            POST /api/play {id}   POST /api/clear {id}
  POST /api/remove   {id, token}  — token returned by /api/publish

Auth: publish issues a per-entry token; remove requires it. The token
is never exposed by /api/feed (not selected). Name-matching alone let
anyone retire a level; the token is the actual auth boundary for
self-hosted instances shared with strangers on a LAN.

CORS is `*`: the feed is PUBLIC read-only data and auth travels in the
POST body (no cookies/credentials), so an open policy leaks nothing.
Error payloads carry a stable "code" for clients, plus "error" text.

Why SQLite and not a JSON file: counters are atomic SQL updates (no
read-modify-write race even if application locking were wrong), the
store survives partial writes, and feed queries use an index instead
of loading the whole catalogue on every request.
"""

import argparse
import json
import os
import secrets
import sqlite3
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

_rate_lock = threading.Lock()
_rate: dict[str, list] = {}          # ip -> timestamps de mutaciones
# in-memory by design: a self-hosted single process needs nothing
# more; multi-instance deployments should rate-limit at the proxy.

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.environ.get("SKM_DB", os.path.join(BASE, "community.db"))
LEGACY_JSON = os.path.join(BASE, "community_db.json")

RATE_WINDOW = 60.0                   # s
RATE_MAX = int(os.environ.get("SKM_RATE_MAX", "30"))   # POST/min por IP
# el juego legítimo hace ≤ ~5/min (publish+like+clear)

MAX_ENTRIES = int(os.environ.get("SKM_MAX_ENTRIES", "5000"))
MAX_ENTRY_BYTES = 64 * 1024          # a level payload is a few KB
MAX_TITLE = 120
MAX_AUTHOR = 40
MAX_BOARD_ROWS = 80                  # el editor permite hasta 64×48;
MAX_BOARD_LINE = 128                 # esto deja margen sin abusos
FEED_MAX_LIMIT = 200

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
                  " ON entries(ts DESC, id)")
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


def _feed(offset: int, limit: int) -> dict:
    """Página del feed — ts+id como orden determinista (dos niveles
    publicados en el mismo segundo no se reordenan entre páginas)."""
    with _conn() as c:
        total = c.execute("SELECT COUNT(*) FROM entries").fetchone()[0]
        rows = c.execute(
            "SELECT id,title,author,data,rules,difficulty,par,ts,"
            "likes,plays,clears FROM entries"
            " ORDER BY ts DESC, id DESC LIMIT ? OFFSET ?",
            (limit, offset)).fetchall()
    out = []
    for r in rows:
        e = dict(zip(_COLS, r))
        for k in ("data", "rules"):
            try:
                e[k] = json.loads(e[k])
            except json.JSONDecodeError:
                e[k] = {} if k == "data" else []
        out.append(e)
    return {"entries": out, "total": total,
            "offset": offset, "limit": limit}


def _sanitize(e: dict) -> dict | None:
    """Strict entry shape — anything else is rejected.
    LevelData.to_dict() emits {board, over, rules, …} — 'board' is the
    newline-joined grid string."""
    if not (isinstance(e.get("data"), dict)
            and isinstance(e["data"].get("board"), str)):
        return None
    board = e["data"]["board"]
    lines = board.split("\n")
    if not lines or len(lines) > MAX_BOARD_ROWS \
            or any(len(ln) > MAX_BOARD_LINE for ln in lines):
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
        "title": e["title"].strip(), "author": e["author"].strip(),
        "data": json.dumps(e["data"], ensure_ascii=False),
        "rules": json.dumps([str(r)[:24] for r in rules],
                          ensure_ascii=False),
        "difficulty": max(0, min(5, int(e.get("difficulty", 1) or 1))),
        "par": max(0, int(e.get("par", 0) or 0)),
        "ts": int(time.time()),
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "SokobanCommunity/2.1"
    protocol_version = "HTTP/1.1"

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
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:
        u = urlparse(self.path)
        path = u.path.rstrip("/")
        if path == "/api/feed":
            try:
                q = parse_qs(u.query)
                offset = max(0, int(q.get("offset", ["0"])[0]))
                limit = min(FEED_MAX_LIMIT,
                            max(1, int(q.get("limit",
                                             [str(FEED_MAX_LIMIT)])[0])))
            except ValueError:
                self._json(400, {"error": "bad pagination"},
                           "bad_query")
                return
            self._json(200, _feed(offset, limit))
        elif path == "/api/health":
            # health real: sin DB el servicio está caído aunque responda
            try:
                with _conn() as c:
                    c.execute("SELECT 1")
                self._json(200, {"ok": True})
            except sqlite3.Error:
                self._json(503, {"ok": False}, "db_down")
        else:
            self._json(404, {"error": "not found"}, "not_found")

    def do_POST(self) -> None:
        path = urlparse(self.path).path.rstrip("/")
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
                    SELECT id FROM entries ORDER BY ts DESC, id DESC
                    LIMIT ?)""", (MAX_ENTRIES,))
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


def main() -> None:
    ap = argparse.ArgumentParser(description="Sokoban Mutante community backend")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--db", default=None,
                    help="SQLite file (default: server/community.db or SKM_DB)")
    args = ap.parse_args()
    global DB
    if args.db:
        DB = args.db
    _init_db()
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    srv.daemon_threads = True   # un cliente colgado no retiene el shutdown
    print(f"Sokoban community server on http://{args.host}:{args.port}"
          f" — db: {os.path.basename(DB)}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        srv.server_close()


if __name__ == "__main__":
    main()
