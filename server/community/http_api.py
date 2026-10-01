"""Capa HTTP: parseo, CORS, rate-limit, serialización y dispatch.

Toda la lógica de dominio vive en routes.py — aquí solo hay
conversión de wire format a `Req` y de la tupla
(status, body, code) de vuelta a bytes.
"""

import json
import logging
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse

from . import config, routes, stats, store

log = logging.getLogger("skm.community")


class Handler(BaseHTTPRequestHandler):
    server_version = f"SokobanCommunity/{config.VERSION}"
    protocol_version = "HTTP/1.1"

    def setup(self) -> None:
        super().setup()
        # un socket sin timeout deja un thread vivo por cada cliente
        # que no envía nada (slowloris)
        self.request.settimeout(config.SOCKET_TIMEOUT)

    def handle_one_request(self) -> None:
        # un read que expira cierra la conexión en vez de propagar
        # un traceback de socket por request lento
        try:
            super().handle_one_request()
        except (TimeoutError, OSError):
            self.close_connection = True

    # ----------------------------------------------------- helpers

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods",
                         "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers",
                         "Content-Type, Authorization")

    def _json(self, code: int, obj, err_code: str = "") -> None:
        stats.bump("requests")
        if code >= 400:
            stats.bump("errors")
            if isinstance(obj, dict):
                obj = {"code": err_code or "error", **obj}
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args) -> None:
        log.info("%s %s", self.client_address[0], fmt % args)

    # ------------------------------------------------------ métodos

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:
        u = urlparse(self.path)
        r = routes.Req(query=u.query, headers=self.headers,
                       ip=self.client_address[0])
        status, body, code = routes.dispatch("GET", u.path, r)
        self._json(status, body, code)

    def do_POST(self) -> None:
        u = urlparse(self.path)
        ip = self.client_address[0]
        # rate-limit por IP en SQLite (ventana deslizante,
        # multi-proceso) — antes de cualquier parseo
        if store.rate_limited(ip):
            stats.bump("rate_limited")
            log.warning("rate_limited ip=%s path=%s", ip, u.path)
            self._json(429, {"error": "rate limited"}, "rate_limited")
            return
        try:
            n = int(self.headers.get("Content-Length", 0))
        except ValueError:
            n = 0
        if not 0 < n <= config.MAX_ENTRY_BYTES + 4096:
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
        r = routes.Req(body=body, headers=self.headers, ip=ip)
        status, out, code = routes.dispatch("POST", u.path, r)
        self._json(status, out, code)
