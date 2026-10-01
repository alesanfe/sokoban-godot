# Modelo de datos

## Servidor (`server/community.db`, SQLite WAL)

```sql
entries  (id PK, token, title, author, data JSON, rules JSON,
          difficulty, par, ts, likes, plays, clears, user, verified)
users    (username PK, pw pbkdf2, salt, ts)
sessions (token PK, user, ts, expires)   -- TTL deslizante
likes    (entry_id, user, PK(entry_id,user))
rate     (ip, ts)                        -- ventana deslizante
```

- `entries.token`: credencial legacy de borrado; jamás en `/api/feed`.
- `entries.user`: cuenta propietaria (NULL en importaciones legacy).
- Borrado en cascada: `remove` limpia `likes` huérfanos.
- Podas automáticas: `rate` > ventana, `sessions` caducadas, catálogo
  a `MAX_ENTRIES`.

## Cliente (`user://`, JSON atómico `.tmp`+rename, `.bak` fallback)

| Fichero | Contenido | Clave |
|---|---|---|
| progress.json | best/replays por nivel | `content_code` (board+rules) |
| settings.json | opciones, `community_remote_url/token/user` | — |
| my_levels.json | niveles creados en el editor | id contenido |
| community.json | catálogo local + `remote_entries` espejo | id / `r:<rid>` |
| records | medallas, badges, daily streak | level id |

- Progreso por `content_code`: renombrar/editar metadatos no huerfana
  récords; los códigos `to_code` legacy siguen leyéndose.
- El token Bearer vive solo en `settings.json` (local al dispositivo);
  `logout` lo borra y un 401 también.

## Clasificación

| Datos | Clase | Control |
|---|---|---|
| Passwords | sensibles | pbkdf2 100k+salt, nunca en logs |
| Bearer tokens | sensibles | TTL, no expuestos por API ni logs |
| Niveles publicados | públicos | feed abierto por diseño |
| IPs en `rate` | técnicos | efímeros (≤60 s), solo anti-abuso |
| Progreso local | del jugador | `user://` del dispositivo, sin envío |
