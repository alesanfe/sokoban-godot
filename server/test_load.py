#!/usr/bin/env python3
"""Test de capacidad del backend de comunidad.

Levanta el servidor real en un puerto efímero con DB temporal y
lanza carga concurrente: lectores de feed + escritores
(register/publish/like). Falla si hay 5xx, si el feed queda
inconsistente o si la latencia p95 supera el presupuesto.

Uso:  python server/test_load.py            (arranca su propio server)
      python server/test_load.py --url http://127.0.0.1:8765
"""

import argparse
import json
import statistics
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
import urllib.error
import os

READERS = 20
WRITERS = 10
REQS_PER_READER = 10         # 200 GETs
P95_FEED_MS = 1000           # presupuesto generoso para CI/WSL
P95_POST_MS = 3000           # writes serializadas (BEGIN IMMEDIATE);
                             # en disco lento local p95≈2s es normal


def req(url, method="GET", body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, headers=headers,
                               method=method)
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(r, timeout=15) as resp:
            return resp.status, json.loads(resp.read()), \
                (time.monotonic() - t0) * 1000
    except urllib.error.HTTPError as e:
        try:
            payload = json.loads(e.read())
        except Exception:
            payload = {}
        return e.code, payload, (time.monotonic() - t0) * 1000


def p95(xs):
    xs = sorted(xs)
    return xs[int(len(xs) * 0.95) - 1] if xs else 0.0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default=None)
    args = ap.parse_args()

    proc = None
    url = args.url
    if url is None:
        dbf = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        dbf.close()
        os.unlink(dbf.name)
        srv = os.path.join(os.path.dirname(__file__),
                           "community_server.py")
        proc = subprocess.Popen(
            [sys.executable, srv, "--host", "127.0.0.1",
             "--port", "18777", "--db", dbf.name],
            env={**os.environ, "SKM_RATE_MAX": "100000"},  # la carga
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)  # no
        url = "http://127.0.0.1:18777"                      # cuenta
        for _ in range(50):                                # como abuso
            try:
                code, _, _ = req(url + "/api/health")
                if code == 200:
                    break
            except Exception:
                pass
            time.sleep(0.1)
        else:
            print("FAIL: server no arranca")
            proc.kill()
            return 1

    fails = 0

    def ok(cond, msg):
        nonlocal fails
        if not cond:
            fails += 1
            print("  FAIL:", msg)
        else:
            print("  ok:", msg)

    try:
        # un usuario publica N niveles (vanilla + solución real)
        code, b, _ = req(url + "/api/register", "POST",
                         {"username": "loaduser", "password": "pw1234"})
        ok(code == 200, "register")
        token = b.get("token", "")
        boards = ["#####\n#@$.#\n#####"] * 5
        ids = []
        for i, board in enumerate(boards):
            code, b, _ = req(url + "/api/publish", "POST", {
                "title": f"load{i}", "data": {"board": board},
                "moves": "r"}, token)
            ok(code == 201, f"publish {i} -> {code}")
            if code == 201:
                ids.append(b["id"])

        get_ms, post_ms, errs = [], [], []

        def reader():
            for _ in range(REQS_PER_READER):
                code, _, ms = req(url + "/api/feed?limit=20")
                get_ms.append(ms)
                if code >= 500:
                    errs.append(code)

        def writer():
            for rid in ids:
                code, _, ms = req(url + "/api/like", "POST",
                                  {"id": rid}, token)
                post_ms.append(ms)
                if code >= 500:
                    errs.append(code)

        threads = ([threading.Thread(target=reader)
                    for _ in range(READERS)] +
                   [threading.Thread(target=writer)
                    for _ in range(WRITERS)])
        t0 = time.monotonic()
        for t in threads:
            t.start()
        for t in threads:
            t.join(60)
        dur = time.monotonic() - t0

        total = READERS * REQS_PER_READER + WRITERS * len(ids)
        ok(not errs, f"0 respuestas 5xx bajo carga ({len(errs)})")
        ok(p95(get_ms) < P95_FEED_MS,
           f"feed p95 {p95(get_ms):.0f} ms < {P95_FEED_MS} ms")
        ok(p95(post_ms) < P95_POST_MS,
           f"like p95 {p95(post_ms):.0f} ms < {P95_POST_MS} ms")
        print(f"  · {total} reqs en {dur:.1f}s "
              f"({total / max(dur, 0.001):.0f} req/s)")

        # consistencia: likes toggle-off si se hicieron N veces par
        code, feed, _ = req(url + "/api/feed?limit=50")
        ent = {e["id"]: e for e in feed["entries"]}
        for rid in ids:
            exp = WRITERS % 2            # toggle par -> 0, impar -> 1
            ok(ent.get(rid, {}).get("likes") == exp,
               f"likes({rid[:6]}) == {exp} (toggle concurrencia)")

        # stats admin
        code, s, _ = req(url + "/api/stats", token=token)
        ok(code in (200, 403),
           f"stats -> {code} (403 si loaduser no es admin)")
    finally:
        if proc is not None:
            proc.kill()
            try:
                os.unlink(dbf.name)
            except OSError:
                pass

    print("== load:", "OK" if fails == 0 else f"{fails} FALLOS", "==")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
