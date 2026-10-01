"""Capa de persistencia: SQLite en WAL, una conexión por operación
(los threads no comparten nada mutable). Las mutaciones de una misma
clave van en `BEGIN IMMEDIATE` — serializa check+write bajo
concurrencia sin advisory locks externos."""

import json
import os
import secrets
import sqlite3
import time

from . import config


def conn() -> sqlite3.Connection:
    c = sqlite3.connect(config.DB, timeout=10)
    c.execute("PRAGMA journal_mode=WAL")
    return c


def init_db() -> None:
    with conn() as c:
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
        for col, ddl in (
            ("user", "ALTER TABLE entries ADD COLUMN user TEXT"),
            ("verified",
             "ALTER TABLE entries ADD COLUMN verified INTEGER DEFAULT 0"),
            ("expires",
             "ALTER TABLE sessions ADD COLUMN expires INTEGER DEFAULT 0"),
        ):
            try:
                c.execute(ddl)
            except sqlite3.OperationalError:
                pass                # la columna ya existe
        _migrate_legacy(c)
        # poda al arrancar: rate fuera de ventana y sesiones muertas
        c.execute("DELETE FROM rate WHERE ts < ?",
                  (time.time() - config.RATE_WINDOW,))
        c.execute("DELETE FROM sessions WHERE expires > 0"
                  " AND expires < ?", (int(time.time()),))


def _migrate_legacy(c: sqlite3.Connection) -> None:
    """Importación única desde el store JSON anterior."""
    path = config.LEGACY_JSON
    if not os.path.exists(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
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
                   str(e.get("title", ""))[:config.MAX_TITLE],
                   str(e.get("author", ""))[:config.MAX_AUTHOR],
                   json.dumps(e.get("data", {}), ensure_ascii=False),
                   json.dumps(e.get("rules", []), ensure_ascii=False),
                   int(e.get("difficulty", 1) or 1),
                   int(e.get("par", 0) or 0),
                   int(e.get("ts", 0)),
                   int(e.get("likes", 0)), int(e.get("plays", 0)),
                   int(e.get("clears", 0))))
    os.replace(path, path + ".migrated")


def rate_limited(ip: str) -> bool:
    """Ventana deslizante por IP persistida en SQLite — correcta bajo
    concurrencia (BEGIN IMMEDIATE serializa) y compartida entre
    procesos que usen la misma DB."""
    now = time.time()
    with conn() as c:
        c.execute("BEGIN IMMEDIATE")
        c.execute("DELETE FROM rate WHERE ts < ?",
                  (now - config.RATE_WINDOW,))
        n = c.execute("SELECT COUNT(*) FROM rate WHERE ip=?",
                      (ip,)).fetchone()[0]
        if n >= config.RATE_MAX:
            c.execute("ROLLBACK")
            return True
        c.execute("INSERT INTO rate VALUES(?,?)", (ip, now))
    return False
