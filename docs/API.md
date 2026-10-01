# API del backend de comunidad

`server/community_server.py` — JSON REST, stdlib, SQLite (WAL).

## Auth

- `Authorization: Bearer <token>` — token devuelto por register/login.
- Las sesiones caducan a `SKM_SESSION_DAYS` (30 por defecto) con
  renovación deslizante por uso; expirada → `401 token_expired` y el
  cliente cierra sesión local automáticamente.
- Requerido en: `publish`, `like`, `remove` (o `token` legacy en body).
- Anónimo: `feed`, `health`, `play`, `clear`.
- Admins (`SKM_ADMINS`, csv de usernames): pueden borrar cualquier
  entrada y leer `/api/stats`.

## Endpoints

| Método+path | Body | Respuesta | Auth |
|---|---|---|---|
| POST `/api/register` | `{username, password}` | `{token, username}` · `409 user_exists` `422 invalid_user` | — |
| POST `/api/login` | `{username, password}` | `{token, username}` · `401 bad_credentials` (sin enumeración) | — |
| GET `/api/feed?offset&limit` | — | `{entries[], total, offset, limit}` (limit ≤ 200; cada entry incluye `verified`) | — |
| GET `/api/health` | — | `{ok:true}` · `503 db_down` | — |
| GET `/api/stats` | — | `{entries, users, sessions_live, likes, requests, errors, rate_limited, uptime_s, version}` | admin |
| POST `/api/publish` | `{title, data, rules?, moves, difficulty?, par?}` | `{id, token, verified}` · `401` `422 invalid_entry` `422 unsolved` | ✓ |
| POST `/api/like` | `{id}` | `{liked, likes}` — toggle por cuenta | ✓ |
| POST `/api/play` `/api/clear` | `{id}` | `{ok:true}` · `404 unknown_id` | — |
| POST `/api/remove` | `{id}` o `{id,token}` | `{removed}` · `403 forbidden` | ✓ |
| POST `/api/delete_user` | `{username}` | `{deleted}` — borra cuenta, sesiones, likes y sus entradas · `403` | admin |

## Verificación de soluciones

`moves` = string `l/r/u/d` de la partida ganadora (el cliente lo toma
del replay del playtest). Si el nivel es Sokoban vanilla (sin reglas
mutantes y sin tiles no simulables) el servidor **rejuega** la
solución: si no resuelve → `422 unsolved`; si resuelve →
`verified=1` en el feed. Los niveles con reglas se aceptan con
`verified=0` (su engine vive en el cliente) — moderables por admins.

## Contrato de `data`

`data` es `LevelData.to_dict()`: `{board, over, rules, title, diff, par, v}`.
`board` = grid ASCII multilínea (≤80 filas × 128 cols). El `token` de
cada entrada **nunca** aparece en el feed.

## Errores

`{error: texto, code: estable}` — códigos: `bad_body`, `bad_json`,
`bad_query`, `invalid_entry`, `invalid_user`, `user_exists`,
`bad_credentials`, `auth_required`, `token_expired`, `forbidden`,
`unknown_id`, `not_found`, `rate_limited`, `db_down`, `unsolved`.

## Límites

- Rate-limit: 30 POST/min por IP — ventana deslizante persistida en
  SQLite (compartida entre procesos y reinicios).
- Catálogo: `MAX_ENTRIES` más recientes (env `SKM_MAX_ENTRIES`, 5000).
- Payload: ≤ 68 KB; reglas ≤ 8; título ≤ 120; autor ≤ 40;
  moves ≤ 4000 chars `[lrud]`.

## Config

Flags `--port --host --db --tls-cert --tls-key --log-file`; env
`SKM_DB`, `SKM_MAX_ENTRIES`, `SKM_RATE_MAX`, `SKM_SESSION_DAYS`,
`SKM_ADMINS`, `SKM_TLS_CERT`, `SKM_TLS_KEY` (`server/.env.example`).
Migración automática de `community_db.json` legacy.

## TLS

Nativo: `--tls-cert/--tls-key` (PEM) → https:// directo, TLS ≥ 1.2.
Alternativa: proxy inverso (Caddy `reverse_proxy 127.0.0.1:8765`).
