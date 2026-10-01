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

## Detrás de un proxy con TLS

Caddy mínimo:

```
skm.ejemplo.com {
    reverse_proxy 127.0.0.1:8765
}
```

Bind siempre a `127.0.0.1` cuando haya proxy delante.

## Rollback

El servidor es un único script sin migraciones destructivas —
volver a un commit anterior y arrancar. La migración
`community_db.json` → SQLite es unidireccional: conservar el JSON
hasta validar que el feed responde.

## Límites operativos conocidos

- Rate-limit en memoria → una instancia por DB (o proxy con
  rate-limit propio para multi-instancia).
- Sin rotación de logs (el servidor apenas loguea).
- `MAX_ENTRIES` poda el catálogo: backup antes de bajar el límite.
