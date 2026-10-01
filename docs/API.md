# API del backend de comunidad

`server/community_server.py` — JSON REST, stdlib, SQLite (WAL).

## Auth

- `Authorization: Bearer <token>` — token devuelto por register/login.
- Requerido en: `publish`, `like`, `remove` (o `token` legacy en body).
- Anónimo: `feed`, `health`, `play`, `clear`.

## Endpoints

| Método+path | Body | Respuesta | Auth |
|---|---|---|---|
| POST `/api/register` | `{username, password}` | `{token, username}` · `409 user_exists` `422 invalid_user` | — |
| POST `/api/login` | `{username, password}` | `{token, username}` · `401 bad_credentials` (sin enumeración) | — |
| GET `/api/feed?offset&limit` | — | `{entries[], total, offset, limit}` (limit ≤ 200) | — |
| GET `/api/health` | — | `{ok:true}` · `503 db_down` | — |
| POST `/api/publish` | `{title, data, rules?, difficulty?, par?}` | `{id, token}` · `401 auth_required` `422 invalid_entry` | ✓ |
| POST `/api/like` | `{id}` | `{liked, likes}` — toggle por cuenta | ✓ |
| POST `/api/play` `/api/clear` | `{id}` | `{ok:true}` · `404 unknown_id` | — |
| POST `/api/remove` | `{id}` o `{id,token}` | `{removed}` · `403 forbidden` | ✓ |

## Contrato de `data`

`data` es `LevelData.to_dict()`: `{board, over, rules, title, diff, par, v}`.
`board` = grid ASCII multilínea (≤80 filas × 128 cols). El `token` de
cada entrada **nunca** aparece en el feed.

## Errores

`{error: texto, code: estable}` — códigos: `bad_body`, `bad_json`,
`bad_query`, `invalid_entry`, `invalid_user`, `user_exists`,
`bad_credentials`, `auth_required`, `forbidden`, `unknown_id`,
`not_found`, `rate_limited`, `db_down`.

## Límites

- Rate-limit: 30 POST/min por IP (ventana deslizante, en proceso).
- Catálogo: `MAX_ENTRIES` más recientes (env `SKM_MAX_ENTRIES`, 5000).
- Payload: ≤ 68 KB; reglas ≤ 8; título ≤ 120; autor ≤ 40.

## Config

`--port`/`--host`/`--db` o env `SKM_DB`, `SKM_MAX_ENTRIES`,
`SKM_RATE_MAX`. Migración automática de `community_db.json` legacy.

## Despliegue con TLS

El servidor no habla HTTPS. Para exponerlo: proxy inverso
(Caddy: `skm.ejemplo.com { reverse_proxy 127.0.0.1:8765 }` da TLS
automático) y bind a `127.0.0.1` con `--host`.
