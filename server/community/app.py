"""Arranque: argparse, logging, TLS y serve_forever.

Los defaults vienen de env (`SKM_*`, ver .env.example); los flags
los sobreescriben. TLS es opt-in — sin cert/key sirve http:// plano
(LAN, o detrás de un proxy que ya termine TLS).
"""

import argparse
import logging
import logging.handlers
import os
import ssl
import sys
from http.server import ThreadingHTTPServer

from . import config, store
from .http_api import Handler

log = logging.getLogger("skm.community")


class _HTTPServer(ThreadingHTTPServer):
    daemon_threads = True  # un cliente colgado no retiene shutdown
    # socketserver deja el listen backlog en 5 — con lectores/escritores
    # concurrentes el kernel rechaza (ConnectionResetError) antes de que
    # accept() llegue. Va como atributo de clase: el listen() ya ocurre
    # en __init__ via server_activate.
    request_queue_size = 128


def make_server(host: str, port: int) -> ThreadingHTTPServer:
    return _HTTPServer((host, port), Handler)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Sokoban Mutante community backend")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--host", default="0.0.0.0")   # nosec B104: bind
    # abierto deliberado — con TLS o proxy delante; LAN por defecto
    ap.add_argument("--db", default=None,
                    help="SQLite file (default: server/community.db"
                         " or SKM_DB)")
    ap.add_argument("--tls-cert",
                    default=os.environ.get("SKM_TLS_CERT", ""),
                    help="PEM cert chain — habilita https:// nativo")
    ap.add_argument("--tls-key",
                    default=os.environ.get("SKM_TLS_KEY", ""),
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

    if args.db:
        config.DB = args.db
    store.init_db()
    srv = make_server(args.host, args.port)
    scheme = "http"
    if args.tls_cert and args.tls_key:
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.minimum_version = ssl.TLSVersion.TLSv1_2
        ctx.load_cert_chain(args.tls_cert, args.tls_key)
        srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
        scheme = "https"
    elif bool(args.tls_cert) != bool(args.tls_key):
        log.warning("TLS incompleto (cert sin key o al revés) "
                    "— http plano")
    print(f"Sokoban community server on "
          f"{scheme}://{args.host}:{args.port}"
          f" — db: {os.path.basename(config.DB)}")
    log.info("start scheme=%s host=%s port=%d admins=%d",
             scheme, args.host, args.port, len(config.ADMINS))
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        srv.server_close()
