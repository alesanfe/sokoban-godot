# Operación del backend de comunidad

## Arranque

```powershell
python server/community_server.py --port 8765 --host 127.0.0.1 \
  --db data/community.db
```

Health: `GET /api/health` → `{ok:true}` (hace `SELECT 1` real;
`503 db_down` si SQLite no responde).

## Configuración

Ver `server/.env.example`: `SKM_DB`, `SKM_MAX_ENTRIES`, `SKM_RATE_MAX`.
Los flags de línea tienen prioridad sobre el env.

## Backup y restauración

SQLite WAL — **no copiar el .db a mano** con el servidor corriendo.

```powershell
# backup en caliente (consistente)
sqlite3 data/community.db ".backup 'backups/community-YYYYMMDD.db'"

# restaurar: parar servidor, reemplazar db, arrancar
```

Verificación de restauración (barata, hacerla de vez en cuando):
levantar con `--db backup.db` en otro puerto y comprobar
`/api/feed?limit=1` y `/api/health`.

## TLS

Nativo, sin proxy:

```powershell
python server/community_server.py --port 8765 \
  --tls-cert certs/fullchain.pem --tls-key certs/privkey.pem
```

o vía env `SKM_TLS_CERT`/`SKM_TLS_KEY`. Alternativa con proxy —
Caddy mínimo:

```
skm.ejemplo.com {
    reverse_proxy 127.0.0.1:8765
}
```

Bind siempre a `127.0.0.1` cuando haya proxy delante.

## Observabilidad

- `GET /api/stats` (Bearer de admin): entradas, usuarios, sesiones
  vivas, likes, requests/errores/rate-limits del proceso, uptime.
- Log estructurado a stderr; `--log-file app.log` añade rotación
  1MB×3. Eventos: start, register, login_fail, publish, remove,
  rate_limited — nunca passwords ni tokens.

## Multi-instancia

El rate-limit vive en SQLite (`rate` table, BEGIN IMMEDIATE) y las
sesiones/likes en la misma DB: varios procesos contra la misma DB
comparten límites, cuentas y feed. Sessiones con TTL deslizante.

## Rollback

El servidor es un único script sin migraciones destructivas —
volver a un commit anterior y arrancar. La migración
`community_db.json` → SQLite es unidireccional: conservar el JSON
hasta validar que el feed responde.

## Límites operativos conocidos

- `MAX_ENTRIES` poda el catálogo: backup antes de bajar el límite.
- Sin revocación manual de usuarios (borrado de cuenta = SQL manual);
  las sesiones caducan solas.
