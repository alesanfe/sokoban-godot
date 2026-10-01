# ADR-004: Backend de comunidad en stdlib + SQLite

## Contexto

El feed de comunidad necesitaba un backend autoalojable sin arrastrar
frameworks ni DBs externas a un juego de puzzle.

## Decisión

Python stdlib (`http.server` threading + `sqlite3` WAL + `pbkdf2`).
Cuentas con Bearer, likes por cuenta, feed paginado, rate-limit en
memoria.

## Alternativas

- JSON file: era la primera versión — race RMW, carga completa cada
  request. Migrado a SQLite.
- Flask/FastAPI + Postgres: más maduro, pero exige instalación y
  fricción para quien autoaloja; evaluado como sobredimensionado.

## Consecuencias

+ Cero dependencias: `python community_server.py` y funciona.
+ WAL permite lecturas concurrentes con escrituras.
- Rate-limit en memoria: multi-instancia necesita proxy.
- No hay moderación de contenidos — scope LAN/amigos + proxy con TLS.
