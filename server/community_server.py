#!/usr/bin/env python3
"""Community backend for Sokoban Mutante — self-hosted, stdlib only.

Run:    python server/community_server.py [--port N] [--host A] [--db F]
                                        [--tls-cert F --tls-key F]
                                        [--log-file F]
Config: SKM_DB, SKM_MAX_ENTRIES, SKM_RATE_MAX, SKM_SESSION_DAYS,
        SKM_ADMINS (csv), SKM_TLS_CERT, SKM_TLS_KEY (env fallbacks)
Data:   server/community.db (SQLite, WAL — safe under ThreadingHTTPServer
        and across processes; migrates a legacy community_db.json)

Endpoints (all JSON):
  POST /api/register {username, password} -> {"token", "username"}
  POST /api/login    {username, password} -> {"token", "username"}
  GET  /api/feed?offset=N&limit=M    -> {"entries":[…], "total", …}
  GET  /api/health                   -> {"ok": true}  (SELECT 1 real)
  GET  /api/stats                    -> counters   (Bearer de admin)
  POST /api/publish  {title, data, rules, moves, par?}
                   -> {"id", "token", "verified"}   (Bearer)
  POST /api/like     {id}  -> {"liked", "likes"}    (Bearer, toggle)
  POST /api/play     {id}   POST /api/clear {id}    (anónimos)
  POST /api/remove   {id}  (Bearer del autor o admin) / {id, token}

Auth: register/login issue Bearer tokens that EXPIRE after
SKM_SESSION_DAYS (sliding: cada uso la renueva); publish/like require
a live session; remove requires the owner's session, an admin session,
or the legacy per-entry token. Passwords: pbkdf2_sha256 (100k, salt).
Sessions are random 192-bit tokens; only their expiry lives in the DB.

Verified: publish requires `moves` — the winning move string recorded
by the client's playtest gate. If the level is vanilla-Sokoban
(reachable by simulation without mutant rules) the server replays the
moves and rejects entries that don't solve the board; rule-bearing
levels are marked verified=0 (their engine lives in the client) and
are covered by admin moderation instead.

CORS `*`: feed is PUBLIC read-only, auth travels via Bearer header
(no cookies), so an open policy leaks nothing.
Errors carry a stable "code" field plus "error" text.
"""

import argparse
import hashlib
import json
import logging
import logging.handlers
import os
import re
import secrets
import sqlite3
import ssl
import sys
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

log = logging.getLogger("skm.community")

BASE = os.path.dirname(os.path.abspath(__file__))
DB = os.environ.get("SKM_DB", os.path.join(BASE, "community.db"))
LEGACY_JSON = os.path.join(BASE, "community_db.json")

RATE_WINDOW = 60.0                   # s
RATE_MAX = int(os.environ.get("SKM_RATE_MAX", "30"))   # POST/min por IP
# el juego legítimo hace ≤ ~5/min (publish+like+clear); vive en
# SQLite → compartido entre procesos si hay multi-instancia

MAX_ENTRIES = int(os.environ.get("SKM_MAX_ENTRIES", "5000"))
MAX_ENTRY_BYTES = 64 * 1024          # a level payload is a few KB
MAX_TITLE = 120
MAX_AUTHOR = 40
MAX_BOARD_ROWS = 80                  # el editor permite hasta 64×48;
MAX_BOARD_LINE = 128                 # esto deja margen sin abusos
MAX_MOVES = 4000                     # una solución real son decenas
MAX_RULES = 8
FEED_MAX_LIMIT = 200
USER_RE = re.compile(r"^[A-Za-z0-9_.\-]{3,24}$")
MOVE_RE = re.compile(r"^[lrud]+$")
PBKDF2_ROUNDS = 100_000
SESSION_TTL = float(os.environ.get("SKM_SESSION_DAYS", "30")) * 86400
ADMINS = {u.strip() for u in
          os.environ.get("SKM_ADMINS", "").split(",") if u.strip()}

_COLS = ("id", "title", "author", "data", "rules", "difficulty",
         "par", "ts", "likes", "plays", "clears",
         "verified")                # token NUNCA aquí

_started = time.time()
_stats = {"requests": 0, "errors": 0, "rate_limited": 0}
_stats_lock = __import__("threading").Lock()


def _bump(key: str) -> None:
    with _stats_lock:
        _stats[key] += 1


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
        c.execute("""CREATE TABLE IF NOT EXISTS users(
            username TEXT PRIMARY KEY,
            pw TEXT NOT NULL, salt TEXT NOT NULL, ts INTEGER)""")
        c.execute("""CREATE TABLE IF NOT EXISTS sessions(
            token TEXT PRIMARY KEY, user TEXT NOT NULL,
            ts INTEGER, expires INTEGER)""")
        c.execute("""CREATE TABLE IF NOT EXISTS likes(
            entry_id TEXT NOT NULL, user TEXT NOT NULL,
            PRIMARY KEY(entry_id, user))""")
        # rate-limit en DB (ventana deslizante): compartido entre
        # procesos, no se pierde al reiniciar ni diverge entre workers
        c.execute("""CREATE TABLE IF NOT EXISTS rate(
            ip TEXT NOT NULL, ts REAL NOT NULL)""")
        c.execute("CREATE INDEX IF NOT EXISTS idx_rate_ip"
                  " ON rate(ip, ts)")
        # migraciones suaves de esquema
        for table, col, ddl in (
            ("entries", "user", "ALTER TABLE entries ADD COLUMN user TEXT"),
            ("entries", "verified",
             "ALTER TABLE entries ADD COLUMN verified INTEGER DEFAULT 0"),
            ("sessions", "expires",
             "ALTER TABLE sessions ADD COLUMN expires INTEGER DEFAULT 0"),
        ):
            try:
                c.execute(ddl)
            except sqlite3.OperationalError:
                pass                # la columna ya existe
        # migración desde el store JSON anterior (una sola vez)
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
        # poda de filas de rate y sesiones caducadas al arrancar
        c.execute("DELETE FROM rate WHERE ts < ?", (time.time() - RATE_WINDOW,))
        c.execute("DELETE FROM sessions WHERE expires > 0 AND expires < ?",
                  (int(time.time()),))


def _feed(offset: int, limit: int) -> dict:
    """Página del feed — ts+id como orden determinista."""
    with _conn() as c:
        total = c.execute("SELECT COUNT(*) FROM entries").fetchone()[0]
        rows = c.execute(
            # nosec en la línea del literal concatenado: _COLS cte
            "SELECT " + ",".join(_COLS) + " FROM entries"  # nosec B608
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


def _hash_pw(password: str, salt: str) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"),
                               bytes.fromhex(salt), PBKDF2_ROUNDS).hex()


def _auth(headers) -> tuple[str | None, bool, bool]:
    """Authorization: Bearer <token> → (username|None, admin, expired).

    Caducidad deslizante: cada uso renueva `expires`; las sesiones
    caducadas se borran y se distinguen con `expired` para que el
    cliente sepa pedir login de nuevo (401 token_expired)."""
    h = headers.get("Authorization", "")
    if not h.startswith("Bearer ") or len(h) > 128:
        return None, False, False
    tok = h[7:]
    now = int(time.time())
    with _conn() as c:
        row = c.execute("SELECT user,ts,expires FROM sessions"
                        " WHERE token=?", (tok,)).fetchone()
        if row is None:
            return None, False, False
        user, ts, exp = row
        exp = exp or (ts + SESSION_TTL)     # sesiones legacy: TTL desde ts
        if exp < now:
            c.execute("DELETE FROM sessions WHERE token=?", (tok,))
            return None, False, True
        c.execute("UPDATE sessions SET expires=? WHERE token=?",
                  (now + SESSION_TTL, tok))
    return user, user in ADMINS, False


def _rate_limited(ip: str) -> bool:
    """Ventana deslizante por IP persistida en SQLite — correcta bajo
    concurrencia (BEGIN IMMEDIATE serializa) y compartida entre
    procesos que usen la misma DB."""
    now = time.time()
    with _conn() as c:
        c.execute("BEGIN IMMEDIATE")
        c.execute("DELETE FROM rate WHERE ts < ?", (now - RATE_WINDOW,))
        n = c.execute("SELECT COUNT(*) FROM rate WHERE ip=?",
                      (ip,)).fetchone()[0]
        if n >= RATE_MAX:
            c.execute("ROLLBACK")
            return True
        c.execute("INSERT INTO rate VALUES(?,?)", (ip, now))
    return False


# ---- verificación de soluciones (Sokoban vanilla) -------------------
# El cliente ya exige superar el nivel antes de publicar; el servidor
# REJUEGA esa solución cuando el tablero es simulable sin reglas
# mutantes. 'moves' viaja en el publish (chars l/r/u/d).

_VANILLA_SOLID = {"#"}                    # paredes
_GOAL_CHARS = {".", "*", "+", "%"}        # metas (con o sin ocupante)
_BOX_CHARS = {"$", "*", "%"}              # cajas (suelas o en meta)
_PLAYER_CHARS = {"@", "+"}


def _verify_solution(data: dict, rules: list, moves: str) -> int:
    """0 = no verificable (reglas/tiles mutantes), 1 = verificado,
    -1 = simulable y la solución NO resuelve (rechazo)."""
    if rules:
        return 0                        # las reglas viven en el engine del cliente
    board = data.get("board", "")
    if not isinstance(moves, str) or not MOVE_RE.match(moves) \
            or len(moves) > MAX_MOVES:
        return -1
    over = data.get("over", {}) or {}
    # ocupantes: board da el terreno, over["x,y"] lo que hay encima
    walls, boxes, goals, player = set(), set(), set(), None
    for y, line in enumerate(board.split("\n")):
        for x, ch in enumerate(line):
            occ = str(over.get(f"{x},{y}", ""))
            c = occ if occ else ch
            if c in _VANILLA_SOLID:
                walls.add((x, y))
            if ch in _GOAL_CHARS or c in _GOAL_CHARS:
                goals.add((x, y))
            if c in _BOX_CHARS:
                boxes.add((x, y))
            if c in _PLAYER_CHARS:
                player = (x, y)
    # tiles mutantes que el simulador no entiende → no verificable
    known = _VANILLA_SOLID | _GOAL_CHARS | _BOX_CHARS | _PLAYER_CHARS \
        | {" ", "-", "_"}
    for y, line in enumerate(board.split("\n")):
        for x, ch in enumerate(line):
            occ = str(over.get(f"{x},{y}", ""))
            if (occ if occ else ch) not in known:
                return 0
    if player is None or not goals:
        return -1
    dxdy = {"l": (-1, 0), "r": (1, 0), "u": (0, -1), "d": (0, 1)}
    px, py = player
    for m in moves:
        dx, dy = dxdy[m]
        nx, ny = px + dx, py + dy
        if (nx, ny) in walls:
            continue                    # paso bloqueado: cuenta pero no mueve
        if (nx, ny) in boxes:
            bx, by = nx + dx, ny + dy
            if (bx, by) in walls or (bx, by) in boxes:
                continue                # empuje bloqueado
            boxes.discard((nx, ny))
            boxes.add((bx, by))
        px, py = nx, ny
    return 1 if goals <= boxes else -1


def _sanitize(e: dict) -> dict | None:
    """Strict entry shape — anything else is rejected.
    LevelData.to_dict() emits {board, over, rules, …}."""
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
    if not isinstance(rules, list) or len(rules) > MAX_RULES:
        return None
    return {
        "id": uuid.uuid4().hex[:12],
        "token": secrets.token_hex(16),      # auth de borrado — nunca sale por /feed
        "title": e["title"].strip(), "author": e["author"].strip(),
        "data": json.dumps(e["data"], ensure_ascii=False),
        "rules": json.dumps([str(r)[:24] for r in rules],
                          ensure_ascii=False),
        "difficulty": max(0, min(5,
            int(e.get("difficulty", 1) or 1))),
        "par": max(0, int(e.get("par", 0) or 0)),
        "ts": int(time.time()),
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "SokobanCommunity/3.0"
    protocol_version = "HTTP/1.1"
    # Un socket sin timeout deja un thread vivo por cada cliente que
    # no envía nada (slowloris). 15 s cubre latencias malas reales.
    SOCKET_TIMEOUT = 15.0

    def setup(self) -> None:
        super().setup()
        self.request.settimeout(self.SOCKET_TIMEOUT)

    def handle_one_request(self) -> None:
        # un read que expira cierra la conexión en vez de propagar
        # un traceback de socket por request lento
        try:
            super().handle_one_request()
        except (TimeoutError, OSError):
            self.close_connection = True

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers",
                         "Content-Type, Authorization")

    def _json(self, code: int, obj, err_code: str = "") -> None:
        # errores = {"error": texto, "code": estable}
        _bump("requests")
        if code >= 400:
            _bump("errors")
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
                self._json(400, {"error": "bad pagination"}, "bad_query")
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
        elif path == "/api/stats":
            # métricas operativas — solo admins (expone volumen de uso)
            _me, admin, expired = _auth(self.headers)
            if expired:
                self._json(401, {"error": "session expired"},
                           "token_expired")
                return
            if not admin:
                self._json(403, {"error": "admin only"}, "forbidden")
                return
            with _conn() as c:
                counts = {
                    "entries": c.execute(
                        "SELECT COUNT(*) FROM entries").fetchone()[0],
                    "users": c.execute(
                        "SELECT COUNT(*) FROM users").fetchone()[0],
                    "sessions_live": c.execute(
                        "SELECT COUNT(*) FROM sessions").fetchone()[0],
                    "likes": c.execute(
                        "SELECT COUNT(*) FROM likes").fetchone()[0],
                }
            with _stats_lock:
                s = dict(_stats)
            s.update(counts)
            s["uptime_s"] = int(time.time() - _started)
            s["version"] = self.server_version.split("/", 1)[1]
            self._json(200, s)
        else:
            self._json(404, {"error": "not found"}, "not_found")

    def do_POST(self) -> None:
        path = urlparse(self.path).path.rstrip("/")
        # rate-limit por IP en SQLite (ventana deslizante, multi-proceso)
        if _rate_limited(self.client_address[0]):
            _bump("rate_limited")
            log.warning("rate_limited ip=%s path=%s",
                        self.client_address[0], path)
            self._json(429, {"error": "rate limited"}, "rate_limited")
            return
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

        if path in ("/api/register", "/api/login"):
            user = str(body.get("username", "")).strip()
            pw = str(body.get("password", ""))
            if not USER_RE.match(user):
                self._json(422, {"error": "username 3-24 [A-Za-z0-9_.-]"},
                           "invalid_user")
                return
            if path == "/api/register":
                if len(pw) < 4:
                    self._json(422, {"error": "password min 4"},
                               "invalid_user")
                    return
                salt = secrets.token_hex(8)
                with _conn() as c:
                    try:
                        c.execute("INSERT INTO users VALUES(?,?,?,?)",
                                  (user, _hash_pw(pw, salt), salt,
                                   int(time.time())))
                    except sqlite3.IntegrityError:
                        self._json(409, {"error": "user exists"},
                                   "user_exists")
                        return
                log.info("register user=%s", user)
            else:
                with _conn() as c:
                    row = c.execute("SELECT pw,salt FROM users"
                                    " WHERE username=?",
                                    (user,)).fetchone()
                ok = row is not None and secrets.compare_digest(
                    row[0], _hash_pw(pw, row[1]))
                if not ok:
                    # misma respuesta para user inexistente — no
                    # enumerar cuentas por el mensaje
                    log.info("login_fail user=%s ip=%s",
                             user, self.client_address[0])
                    self._json(401, {"error": "bad credentials"},
                               "bad_credentials")
                    return
            token = secrets.token_hex(24)
            with _conn() as c:
                c.execute("INSERT INTO sessions VALUES(?,?,?,?)",
                          (token, user, int(time.time()),
                           int(time.time() + SESSION_TTL)))
            self._json(200, {"token": token, "username": user})
            return

        if path == "/api/publish":
            me, _adm, expired = _auth(self.headers)
            if me is None:
                self._json(401,
                    {"error": "session expired" if expired
                     else "login required"},
                    "token_expired" if expired else "auth_required")
                return
            body = {**body, "author": me}   # el autor es la cuenta,
            entry = _sanitize(body)         # no un campo del cliente
            if entry is None:
                self._json(422, {"error": "invalid entry"},
                           "invalid_entry")
                return
            # prueba de solución: el playtest del cliente deja 'moves';
            # el servidor los rejuega cuando el nivel es vanilla.
            v = _verify_solution(json.loads(entry["data"]),
                                 json.loads(entry["rules"]),
                                 str(body.get("moves", "")))
            if v == -1:
                self._json(422,
                    {"error": "solution does not solve the board"},
                    "unsolved")
                return
            with _conn() as c:
                c.execute(
                    "INSERT INTO entries(" + ",".join(_COLS) +  # nosec B608
                    ",token,user) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (entry["id"], entry["title"], entry["author"],
                     entry["data"], entry["rules"],
                     entry["difficulty"], entry["par"], entry["ts"],
                     0, 0, 0, v, entry["token"], me))
                # cap de catálogo: conserva los MAX_ENTRIES más nuevos
                c.execute("""DELETE FROM entries WHERE id NOT IN (
                    SELECT id FROM entries ORDER BY ts DESC, id DESC
                    LIMIT ?)""", (MAX_ENTRIES,))
            log.info("publish id=%s user=%s verified=%d",
                     entry["id"], me, v)
            self._json(201, {"id": entry["id"], "token": entry["token"],
                             "verified": v})
            return

        eid = str(body.get("id", ""))
        if path == "/api/remove":
            me, admin, expired = _auth(self.headers)
            if expired:
                self._json(401, {"error": "session expired"},
                           "token_expired")
                return
            with _conn() as c:
                row = c.execute("SELECT token,user FROM entries"
                                " WHERE id=?", (eid,)).fetchone()
                if row is None:
                    self._json(404, {"error": "unknown id"},
                               "unknown_id")
                    return
                # propietario o admin por sesión; token legacy por body
                ok = (me is not None and (row[1] == me or admin)) or \
                    secrets.compare_digest(
                        row[0], str(body.get("token", "")))
                if not ok:
                    self._json(403, {"error": "not the author"},
                               "forbidden")
                    return
                c.execute("DELETE FROM entries WHERE id=?", (eid,))
                c.execute("DELETE FROM likes WHERE entry_id=?", (eid,))
            log.info("remove id=%s by=%s admin=%s",
                     eid, me or "token", admin)
            self._json(200, {"removed": eid})
            return

        if path == "/api/like":
            # like = toggle autenticado por cuenta (PK compuesta)
            me, _adm, expired = _auth(self.headers)
            if me is None:
                self._json(401,
                    {"error": "session expired" if expired
                     else "login required"},
                    "token_expired" if expired else "auth_required")
                return
            with _conn() as c:
                # BEGIN IMMEDIATE serializa el toggle: check+insert no
                # es atómico y dos likes concurrentes de la misma
                # cuenta provocaban IntegrityError por la PK
                c.execute("BEGIN IMMEDIATE")
                if c.execute("SELECT 1 FROM entries WHERE id=?",
                             (eid,)).fetchone() is None:
                    self._json(404, {"error": "unknown id"},
                               "unknown_id")
                    return
                if c.execute("SELECT 1 FROM likes WHERE entry_id=?"
                             " AND user=?", (eid, me)).fetchone():
                    c.execute("DELETE FROM likes WHERE entry_id=?"
                              " AND user=?", (eid, me))
                    liked = False
                else:
                    c.execute("INSERT INTO likes VALUES(?,?)",
                              (eid, me))
                    liked = True
                n = c.execute("SELECT COUNT(*) FROM likes"
                              " WHERE entry_id=?", (eid,)).fetchone()[0]
                c.execute("UPDATE entries SET likes=? WHERE id=?",
                          (n, eid))
            self._json(200, {"liked": liked, "likes": n})
            return

        # /api/delete_user {username}: moderación — un admin elimina la
        # cuenta: sesiones, likes del usuario y sus entradas publicadas.
        if path == "/api/delete_user":
            me, admin, expired = _auth(self.headers)
            if expired:
                self._json(401, {"error": "session expired"},
                           "token_expired")
                return
            if not admin:
                self._json(403, {"error": "admin only"}, "forbidden")
                return
            target = str(body.get("username", "")).strip()
            if not USER_RE.match(target) or target == me:
                # un admin no puede eliminar su propia cuenta por API —
                # evita dejar el servicio sin moderadores por accidente
                self._json(422, {"error": "invalid user"},
                           "invalid_user")
                return
            with _conn() as c:
                c.execute("BEGIN IMMEDIATE")
                if c.execute("DELETE FROM users WHERE username=?",
                             (target,)).rowcount == 0:
                    self._json(404, {"error": "unknown user"},
                               "unknown_id")
                    return
                c.execute("DELETE FROM sessions WHERE user=?",
                          (target,))
                c.execute("DELETE FROM likes WHERE user=?", (target,))
                # recontar likes afectados por likes del usuario borrado
                c.execute("""UPDATE entries SET likes=(
                    SELECT COUNT(*) FROM likes
                    WHERE likes.entry_id=entries.id)""")
                c.execute("DELETE FROM entries WHERE user=?",
                          (target,))
            log.warning("admin_delete_user target=%s by=%s", target, me)
            self._json(200, {"deleted": target})
            return

        # play/clear: contadores anónimos (el juego los emite al
        # abrir/superar un nivel, sin exigir login)
        if path in ("/api/play", "/api/clear"):
            field = path.rsplit("/", 1)[1]
            with _conn() as c:
                cur = c.execute(
                    f"UPDATE entries SET {field}s = {field}s + 1"  # nosec B608
                    # field es "play"|"clear" por el if de arriba
                    " WHERE id = ?", (eid,))
            if cur.rowcount == 0:
                self._json(404, {"error": "unknown id"}, "unknown_id")
                return
            self._json(200, {"ok": True})
            return

        self._json(404, {"error": "not found"}, "not_found")

    def log_message(self, fmt, *args) -> None:
        log.info("%s %s", self.client_address[0], fmt % args)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Sokoban Mutante community backend")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--host", default="0.0.0.0")   # nosec B104: bind
    # abierto deliberado — con TLS o proxy delante; LAN por defecto
    ap.add_argument("--db", default=None,
                    help="SQLite file (default: server/community.db or SKM_DB)")
    ap.add_argument("--tls-cert", default=os.environ.get("SKM_TLS_CERT", ""),
                    help="PEM cert chain — habilita https:// nativo")
    ap.add_argument("--tls-key", default=os.environ.get("SKM_TLS_KEY", ""),
                    help="PEM private key")
    ap.add_argument("--log-file", default=None,
                    help="access/security log rotado (1MB × 3)")
    args = ap.parse_args()

    logging.basicConfig(level=logging.INFO, stream=sys.stderr,
                        format="%(asctime)s %(levelname)s %(message)s")
    if args.log_file:
        h = logging.handlers.RotatingFileHandler(
            args.log_file, maxBytes=1024 * 1024, backupCount=3,
            encoding="utf-8")
        h.setFormatter(logging.Formatter(
            "%(asctime)s %(levelname)s %(message)s"))
        logging.getLogger().addHandler(h)

    global DB
    if args.db:
        DB = args.db
    _init_db()
    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    srv.daemon_threads = True   # un cliente colgado no retiene el shutdown
    scheme = "http"
    if args.tls_cert and args.tls_key:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.minimum_version = ssl.TLSVersion.TLSv1_2
        ctx.load_cert_chain(args.tls_cert, args.tls_key)
        srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
        scheme = "https"
    elif bool(args.tls_cert) != bool(args.tls_key):
        log.warning("TLS incompleto (cert sin key o al revés) — http plano")
    print(f"Sokoban community server on {scheme}://{args.host}:{args.port}"
          f" — db: {os.path.basename(DB)}")
    log.info("start scheme=%s host=%s port=%d admins=%d",
             scheme, args.host, args.port, len(ADMINS))
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        srv.server_close()


if __name__ == "__main__":
    main()
