# Respuesta a incidentes — backend de comunidad

## Severidades

| Sev | Ejemplo | Respuesta |
|---|---|---|
| P1 | Token de otro válido, DB legible, datos filtrados | parar servidor, rotar (borrar `sessions`), revisar log, parche, comunicar |
| P2 | Servicio caído / DB corrupta | restaurar `.backup`/`.bak`, verificar `/api/health` |
| P3 | Spam, abuso de publicación | `SKM_RATE_MAX`, `SKM_ADMINS` → `delete_user` |

## Procedimiento (orden)

1. **Contener**: parar el proceso o bajar el proxy; si hay fuga de
   credenciales, `DELETE FROM sessions` + `DELETE FROM users` del
   afectado (o `/api/delete_user` con admin).
2. **Diagnosticar**: `--log-file` tiene auth_fail/publish/remove/
   rate_limited por IP; `/api/stats` muestra errores y volumen.
3. **Recuperar**: backup `community.db` → arrancar → health → feed.
4. **Post-incidente**: issue con timeline + causa raíz + medida
   preventiva; si es vulnerabilidad, sigue SECURITY.md.

## Evidencias que conservar

- `--log-file` rotado (no tiene secrets por diseño).
- Copia de `community.db` (y `-wal`/`-shm`) antes de restaurar.

## Quién opera

El operador del servidor self-hosted es responsable; el repo provee
las herramientas (`SKM_ADMINS`, `delete_user`, stats, backup).
