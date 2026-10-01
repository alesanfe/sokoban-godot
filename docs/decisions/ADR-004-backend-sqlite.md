# ADR-004: Backend de comunidad en stdlib + SQLite

## Contexto

El feed de comunidad necesitaba un backend autoalojable sin arrastrar
frameworks ni DBs externas a un juego de puzzle. El volumen objetivo
(comunidades de un juego de puzzle self-hosted) son decenas/cientos
de usuarios, no miles de req/s — la exigencia correcta es robustez
y cero fricción, no escala horizontal.

## Decisión

Python stdlib (`http.server` threading + `sqlite3` WAL + `pbkdf2` +
`ssl`): cuentas con Bearer + TTL deslizante, likes por cuenta, feed
paginado, rate-limit **persistido en SQLite** (`BEGIN IMMEDIATE`),
TLS nativo opcional, admins/moderación, stats endpoint, log
rotado, timeout de socket (15 s) por request.

Estructura (paquete `server/community/`): `config` (env+ctes),
`store` (schema/migraciones/rate-limit), `auth` (pbkdf2+sesiones),
`verify` (replay vanilla), `routes` (handlers puros
`(status, body, code)` + tabla ROUTES), `http_api` (Handler
delgado), `app` (argparse/TLS/serve). `community_server.py` es un
shim de compatibilidad.

## Alternativas

- JSON file: era la primera versión — race RMW, carga completa cada
  request. Migrado a SQLite.
- Flask/FastAPI + Postgres: más maduro, pero exige instalación y
  fricción para quien autoaloja; sobredimensionado para este volumen.

## Consecuencias

- Cero dependencias: `python community_server.py` y funciona.
- WAL: lecturas concurrentes; `BEGIN IMMEDIATE` serializa las
  mutaciones de un misma clave (likes, rate-limit) — test de carga
  (`test_load.py`, 250 reqs concurrentes) lo verifica.
- Auto-servible: TLS, health real (toca DB), stats, backup en
  caliente con `.backup`.

- Concurrencia real acotada por el GIL+threading — suficiente para
  el volumen objetivo; `test_load.py` mide el límite.
