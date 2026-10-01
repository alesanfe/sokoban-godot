"""Contadores de proceso para /api/stats (volumen, no PIIs)."""

import threading
import time

_started = time.time()
_stats = {"requests": 0, "errors": 0, "rate_limited": 0}
_lock = threading.Lock()


def bump(key: str) -> None:
    with _lock:
        _stats[key] += 1


def snapshot() -> dict:
    with _lock:
        s = dict(_stats)
    s["uptime_s"] = int(time.time() - _started)
    return s
