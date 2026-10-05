# SLOs del backend de comunidad

Objetivos medibles para `community_server.py` autoalojado. Se miden
con `/api/stats` + el test de carga `server/test_load.py`.

## SLI / SLO

| SLI | Medición | SLO |
|---|---|---|
| Disponibilidad | `/api/health` responde `{ok:true}` con DB viva | ≥ 99 % mensual |
| Latencia feed | p95 de `GET /api/feed` | < 200 ms |
| Latencia mutaciones | p95 de POST publish/like/remove | < 500 ms |
| Errores | `errors / requests` en `/api/stats` | < 1 % (excluye 4xx de cliente) |
| Capacidad | `test_load.py` | 60 req concurrentes, 0 errores 5xx |

## Límites activos que protegen los SLO

- Rate-limit 30 POST/min por IP (`SKM_RATE_MAX`) en SQLite.
- Payload ≤ 68 KB; feed paginado limit ≤ 200.
- Catálogo acotado `SKM_MAX_ENTRIES` (5000).
- Sesiones con TTL deslizante (30 días).
- `daemon_threads`: clientes colgados no bloquean el shutdown.

## Recuperación

- **RPO**: última escritura confirmada en SQLite (WAL). Backup en
  caliente: `sqlite3 db ".backup …"` — ver OPERATIONS.md.
- **RTO**: `python community_server.py --db backup.db` — el servicio
  es un proceso sin estado externo; el tiempo de restauración es el
  de arrancar Python + abrir la DB (segundos).

## Alertas sugeridas (del operador)

- `/api/health` != 200 durante > 1 min → servicio o DB caídos.
- `rate_limited` creciendo en `/api/stats` → abuso sostenido.
- `errors/requests` > 5 % → regresión o DB degradada.
