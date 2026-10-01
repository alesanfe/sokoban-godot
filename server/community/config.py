"""Configuración: toda la superficie tunable del servicio."""

import os
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.environ.get("SKM_DB", os.path.join(BASE, "community.db"))
LEGACY_JSON = os.path.join(BASE, "community_db.json")

RATE_WINDOW = 60.0                                        # s
# el juego legítimo hace ≤ ~5/min (publish+like+clear); vive en
# SQLite → compartido entre procesos si hay multi-instancia
RATE_MAX = int(os.environ.get("SKM_RATE_MAX", "30"))      # POST/min por IP

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

VERSION = "3.1"
SOCKET_TIMEOUT = 15.0    # un socket sin timeout = slowloris trivial
