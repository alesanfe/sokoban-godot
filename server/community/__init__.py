"""Sokoban Mutante community backend — stdlib only.

Capas:
    config.py  — constantes y env
    store.py   — SQLite (schema, migraciones, poda)
    auth.py    — pbkdf2 + sesiones Bearer con TTL deslizante
    verify.py  — replay de soluciones Sokoban vanilla
    stats.py   — contadores de proceso para /api/stats
    routes.py  — handlers puros: (status, body, err_code)
    http_api.py— Handler HTTP delgado: CORS, JSON, dispatch
    app.py     — argparse, logging, TLS, serve

Compat: `python server/community_server.py` sigue funcionando
(es un shim) y `python -m community` (con server/ en sys.path).
"""
