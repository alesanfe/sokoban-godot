"""Auth: pbkdf2-sha256 para passwords, Bearer tokens de 192 bits con
TTL deslizante para sesiones. Solo el estado de sesión vive en DB —
los passwords nunca se almacenan reversibles ni salen por la API."""

import hashlib
import secrets
import time

from . import config, store


def hash_pw(password: str, salt: str) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"),
                               bytes.fromhex(salt),
                               config.PBKDF2_ROUNDS).hex()


def check_password(user: str, password: str) -> bool:
    with store.conn() as c:
        row = c.execute("SELECT pw,salt FROM users WHERE username=?",
                        (user,)).fetchone()
    return row is not None and secrets.compare_digest(
        row[0], hash_pw(password, row[1]))


def register(user: str, password: str) -> bool:
    """True si se creó; False si el username ya existe."""
    import sqlite3
    salt = secrets.token_hex(8)
    with store.conn() as c:
        try:
            c.execute("INSERT INTO users VALUES(?,?,?,?)",
                      (user, hash_pw(password, salt), salt,
                       int(time.time())))
        except sqlite3.IntegrityError:
            return False
    return True


def make_session(user: str) -> str:
    token = secrets.token_hex(24)
    now = int(time.time())
    with store.conn() as c:
        c.execute("INSERT INTO sessions VALUES(?,?,?,?)",
                  (token, user, now, int(now + config.SESSION_TTL)))
    return token


def authenticate(headers) -> tuple[str | None, bool, bool]:
    """Authorization: Bearer <token> → (username|None, admin, expired).

    Caducidad deslizante: cada uso renueva `expires`; las sesiones
    caducadas se borran y se distinguen con `expired` para que el
    cliente sepa pedir login de nuevo (401 token_expired)."""
    h = headers.get("Authorization", "")
    if not h.startswith("Bearer ") or len(h) > 128:
        return None, False, False
    tok = h[7:]
    now = int(time.time())
    with store.conn() as c:
        row = c.execute("SELECT user,ts,expires FROM sessions"
                        " WHERE token=?", (tok,)).fetchone()
        if row is None:
            return None, False, False
        user, ts, exp = row
        exp = exp or (ts + config.SESSION_TTL)  # legacy: TTL desde ts
        if exp < now:
            c.execute("DELETE FROM sessions WHERE token=?", (tok,))
            return None, False, True
        c.execute("UPDATE sessions SET expires=? WHERE token=?",
                  (now + config.SESSION_TTL, tok))
    return user, user in config.ADMINS, False
