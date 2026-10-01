"""Handlers de ruta — lógica pura, sin HTTP.

Cada handler recibe un `Req` (body, query, auth resuelto, ip) y
devuelve `(status, body_dict, err_code)`. Son directamente
testeables: `tests` y `test_load` podrían ejercitarlos sin socket.
La tabla `ROUTES` reemplaza la cadena de elifs: el dispatch es data,
no control de flujo.
"""

import json
import logging
import secrets
import sqlite3
import time
import uuid
from urllib.parse import parse_qs

from . import auth, config, stats, store, verify

log = logging.getLogger("skm.community")

# columnas públicas del feed — token NUNCA está aquí
COLS = ("id", "title", "author", "data", "rules", "difficulty",
        "par", "ts", "likes", "plays", "clears", "verified")


class Req:
    """Contexto de request para los handlers."""

    def __init__(self, body=None, query="", headers=None, ip=""):
        self.body = body if isinstance(body, dict) else {}
        self.query = parse_qs(query)
        self.headers = headers or {}
        self.ip = ip
        self._auth = None

    @property
    def auth(self) -> tuple[str | None, bool, bool]:
        """(user, admin, expired) — lazy: solo toca DB si el handler
        la pide (feed/health/play/clear no la necesitan)."""
        if self._auth is None:
            self._auth = auth.authenticate(self.headers)
        return self._auth


def _need_auth(r: Req) -> tuple | None:
    """None si autenticado; si no, la respuesta 401 para responder."""
    me, _adm, expired = r.auth
    if me is None:
        if expired:
            return 401, {"error": "session expired"}, "token_expired"
        return 401, {"error": "login required"}, "auth_required"
    return None


def _need_admin(r: Req) -> tuple | None:
    _me, admin, expired = r.auth
    if expired:
        return 401, {"error": "session expired"}, "token_expired"
    if not admin:
        return 403, {"error": "admin only"}, "forbidden"
    return None


# --------------------------------------------------------------- GET

def h_feed(r: Req):
    try:
        offset = max(0, int(r.query.get("offset", ["0"])[0]))
        limit = min(config.FEED_MAX_LIMIT,
                    max(1, int(r.query.get(
                        "limit", [str(config.FEED_MAX_LIMIT)])[0])))
    except (ValueError, TypeError):
        return 400, {"error": "bad pagination"}, "bad_query"
    with store.conn() as c:
        total = c.execute("SELECT COUNT(*) FROM entries").fetchone()[0]
        rows = c.execute(
            "SELECT " + ",".join(COLS) + " FROM entries"  # nosec B608
            " ORDER BY ts DESC, id DESC LIMIT ? OFFSET ?",
            (limit, offset)).fetchall()              # COLS = cte interna
    out = []
    for row in rows:
        e = dict(zip(COLS, row))
        for k in ("data", "rules"):
            try:
                e[k] = json.loads(e[k])
            except json.JSONDecodeError:
                e[k] = {} if k == "data" else []
        out.append(e)
    return 200, {"entries": out, "total": total,
                 "offset": offset, "limit": limit}, ""


def h_health(_r: Req):
    """Health real: sin DB el servicio está caído aunque responda."""
    try:
        with store.conn() as c:
            c.execute("SELECT 1")
        return 200, {"ok": True}, ""
    except sqlite3.Error:
        return 503, {"ok": False}, "db_down"


def h_stats(r: Req):
    """Métricas operativas — solo admins (expone volumen de uso)."""
    err = _need_admin(r)
    if err:
        return err
    with store.conn() as c:
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
    s = stats.snapshot()
    s.update(counts)
    s["version"] = config.VERSION
    return 200, s, ""


# -------------------------------------------------------------- POST

def h_register(r: Req):
    user = str(r.body.get("username", "")).strip()
    pw = str(r.body.get("password", ""))
    if not config.USER_RE.match(user):
        return 422, {"error": "username 3-24 [A-Za-z0-9_.-]"}, \
            "invalid_user"
    if len(pw) < 4:
        return 422, {"error": "password min 4"}, "invalid_user"
    if not auth.register(user, pw):
        return 409, {"error": "user exists"}, "user_exists"
    log.info("register user=%s", user)
    return 200, {"token": auth.make_session(user), "username": user}, ""


def h_login(r: Req):
    user = str(r.body.get("username", "")).strip()
    pw = str(r.body.get("password", ""))
    if not config.USER_RE.match(user):
        return 422, {"error": "username 3-24 [A-Za-z0-9_.-]"}, \
            "invalid_user"
    if not auth.check_password(user, pw):
        # misma respuesta para user inexistente — no enumerar cuentas
        # por el mensaje
        log.info("login_fail user=%s ip=%s", user, r.ip)
        return 401, {"error": "bad credentials"}, "bad_credentials"
    return 200, {"token": auth.make_session(user), "username": user}, ""


def _sanitize(e: dict) -> dict | None:
    """Strict entry shape — anything else is rejected."""
    if not (isinstance(e.get("data"), dict)
            and isinstance(e["data"].get("board"), str)):
        return None
    board = e["data"]["board"]
    lines = board.split("\n")
    if not lines or len(lines) > config.MAX_BOARD_ROWS \
            or any(len(ln) > config.MAX_BOARD_LINE for ln in lines):
        return None
    title, author = e.get("title"), e.get("author")
    if not isinstance(title, str) or not 0 < len(title) <= config.MAX_TITLE:
        return None
    if not isinstance(author, str) or not 0 < len(author) <= config.MAX_AUTHOR:
        return None
    rules = e.get("rules", [])
    if not isinstance(rules, list) or len(rules) > config.MAX_RULES:
        return None
    return {
        "id": uuid.uuid4().hex[:12],
        "token": secrets.token_hex(16),  # auth de borrado — nunca por feed
        "title": title.strip(), "author": author.strip(),
        "data": json.dumps(e["data"], ensure_ascii=False),
        "rules": json.dumps([str(x)[:24] for x in rules],
                          ensure_ascii=False),
        "difficulty": max(0, min(5, int(e.get("difficulty", 1) or 1))),
        "par": max(0, int(e.get("par", 0) or 0)),
        "ts": int(time.time()),
    }


def h_publish(r: Req):
    err = _need_auth(r)
    if err:
        return err
    me, _adm, _exp = r.auth
    body = {**r.body, "author": me}    # el autor es la cuenta,
    entry = _sanitize(body)            # no un campo del cliente
    if entry is None:
        return 422, {"error": "invalid entry"}, "invalid_entry"
    # prueba de solución: el playtest del cliente deja 'moves'; el
    # servidor los rejuega cuando el nivel es vanilla
    v = verify.verify_solution(json.loads(entry["data"]),
                               json.loads(entry["rules"]),
                               str(r.body.get("moves", "")))
    if v == -1:
        return 422, {"error": "solution does not solve the board"}, \
            "unsolved"
    with store.conn() as c:
        c.execute(
            "INSERT INTO entries(" + ",".join(COLS) +  # nosec B608
            ",token,user) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (entry["id"], entry["title"], entry["author"],
             entry["data"], entry["rules"], entry["difficulty"],
             entry["par"], entry["ts"], 0, 0, 0, v,
             entry["token"], me))
        # cap de catálogo: conserva los MAX_ENTRIES más nuevos
        c.execute("""DELETE FROM entries WHERE id NOT IN (
            SELECT id FROM entries ORDER BY ts DESC, id DESC
            LIMIT ?)""", (config.MAX_ENTRIES,))
    log.info("publish id=%s user=%s verified=%d", entry["id"], me, v)
    return 201, {"id": entry["id"], "token": entry["token"],
                 "verified": v}, ""


def h_remove(r: Req):
    me, admin, expired = r.auth
    if expired:
        return 401, {"error": "session expired"}, "token_expired"
    eid = str(r.body.get("id", ""))
    with store.conn() as c:
        row = c.execute("SELECT token,user FROM entries WHERE id=?",
                        (eid,)).fetchone()
        if row is None:
            return 404, {"error": "unknown id"}, "unknown_id"
        # propietario o admin por sesión; token legacy por body
        ok = (me is not None and (row[1] == me or admin)) or \
            secrets.compare_digest(row[0], str(r.body.get("token", "")))
        if not ok:
            return 403, {"error": "not the author"}, "forbidden"
        c.execute("DELETE FROM entries WHERE id=?", (eid,))
        c.execute("DELETE FROM likes WHERE entry_id=?", (eid,))
    log.info("remove id=%s by=%s admin=%s", eid, me or "token", admin)
    return 200, {"removed": eid}, ""


def h_like(r: Req):
    err = _need_auth(r)
    if err:
        return err
    me = r.auth[0]
    eid = str(r.body.get("id", ""))
    with store.conn() as c:
        # BEGIN IMMEDIATE serializa el toggle: check+insert no es
        # atómico y dos likes concurrentes de la misma cuenta
        # provocaban IntegrityError por la PK
        c.execute("BEGIN IMMEDIATE")
        if c.execute("SELECT 1 FROM entries WHERE id=?",
                     (eid,)).fetchone() is None:
            return 404, {"error": "unknown id"}, "unknown_id"
        if c.execute("SELECT 1 FROM likes WHERE entry_id=?"
                     " AND user=?", (eid, me)).fetchone():
            c.execute("DELETE FROM likes WHERE entry_id=?"
                      " AND user=?", (eid, me))
            liked = False
        else:
            c.execute("INSERT INTO likes VALUES(?,?)", (eid, me))
            liked = True
        n = c.execute("SELECT COUNT(*) FROM likes WHERE entry_id=?",
                      (eid,)).fetchone()[0]
        c.execute("UPDATE entries SET likes=? WHERE id=?", (n, eid))
    return 200, {"liked": liked, "likes": n}, ""


def h_delete_user(r: Req):
    """Moderación: un admin elimina cuenta, sesiones, likes y
    entradas publicadas del usuario."""
    err = _need_admin(r)
    if err:
        return err
    me = r.auth[0]
    target = str(r.body.get("username", "")).strip()
    if not config.USER_RE.match(target) or target == me:
        # un admin no puede borrarse a sí mismo — el servicio no se
        # queda sin moderadores por accidente
        return 422, {"error": "invalid user"}, "invalid_user"
    with store.conn() as c:
        c.execute("BEGIN IMMEDIATE")
        if c.execute("DELETE FROM users WHERE username=?",
                     (target,)).rowcount == 0:
            return 404, {"error": "unknown user"}, "unknown_id"
        c.execute("DELETE FROM sessions WHERE user=?", (target,))
        c.execute("DELETE FROM likes WHERE user=?", (target,))
        # recontar likes que el usuario borrado había hecho
        c.execute("""UPDATE entries SET likes=(
            SELECT COUNT(*) FROM likes
            WHERE likes.entry_id=entries.id)""")
        c.execute("DELETE FROM entries WHERE user=?", (target,))
    log.warning("admin_delete_user target=%s by=%s", target, me)
    return 200, {"deleted": target}, ""


def _bump_counter(r: Req, field: str):
    """play/clear: contadores anónimos — el juego los emite al
    abrir/superar un nivel, sin exigir login."""
    eid = str(r.body.get("id", ""))
    with store.conn() as c:
        cur = c.execute(  # field solo puede ser "play"|"clear"
            f"UPDATE entries SET {field}s = {field}s + 1"  # nosec B608
            " WHERE id = ?", (eid,))
    if cur.rowcount == 0:
        return 404, {"error": "unknown id"}, "unknown_id"
    return 200, {"ok": True}, ""


def h_play(r: Req):
    return _bump_counter(r, "play")


def h_clear(r: Req):
    return _bump_counter(r, "clear")


def h_not_found(_r: Req):
    return 404, {"error": "not found"}, "not_found"


# --------------------------------------------------------- dispatch
# La tabla es la fuente de verdad del contrato — añadir un endpoint
# es una línea aquí + su handler, no una rama más en una función.

ROUTES = {
    ("GET", "/api/feed"): h_feed,
    ("GET", "/api/health"): h_health,
    ("GET", "/api/stats"): h_stats,
    ("POST", "/api/register"): h_register,
    ("POST", "/api/login"): h_login,
    ("POST", "/api/publish"): h_publish,
    ("POST", "/api/remove"): h_remove,
    ("POST", "/api/like"): h_like,
    ("POST", "/api/delete_user"): h_delete_user,
    ("POST", "/api/play"): h_play,
    ("POST", "/api/clear"): h_clear,
}


def dispatch(method: str, path: str, r: Req) -> tuple:
    """(status, body, err_code) — 404 vía h_not_found por defecto."""
    fn = ROUTES.get((method, path.rstrip("/")))
    return fn(r) if fn else h_not_found(r)
