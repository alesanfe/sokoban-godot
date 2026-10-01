# Modelo de amenazas — backend de comunidad

Scope: `server/community_server.py` — autoalojable en LAN o
expuesto directamente con su TLS nativo (`--tls-cert/--tls-key`) o
detrás de un proxy HTTPS. El juego Godot es local y fuera de scope
salvo el token Bearer persistido en `user://`.

## Activos y controles

| Activo | Amenaza | Control |
|---|---|---|
| Passwords | robo de DB | pbkdf2_sha256 100k + salt por usuario |
| Tokens Bearer | robo en tránsito | TLS nativo o proxy; caducan a los `SKM_SESSION_DAYS` (30 días, renovación deslizante por uso) |
| Identidad del autor | suplantación | `author` fijado por el servidor desde la sesión; el campo del body se ignora |
| Feed | DoS por spam | rate-limit por IP en SQLite (compartido entre procesos), payload ≤68 KB, `MAX_ENTRIES` |
| Borrado | remove ajeno | Bearer del propietario, admin (`SKM_ADMINS`) o token legacy no expuesto por `/api/feed` |
| Likes | multi-voto | PK `(entry_id, user)`, toggle real server-side |
| Niveles insolubles | spam de feed | publish exige `moves`; el servidor rejuega la solución y rechaza (`422 unsolved`) niveles vanilla que no cierran; con reglas mutantes quedan `verified=0` y los admins pueden retirarlos |

## Vectores verificados

- **Inyección SQL**: consultas parametrizadas en todo el servidor. ✅
- **User enumeration**: register→409 público; login da la misma
  respuesta para usuario inexistente y password malo. ✅
- **CSRF**: sin cookies → no aplica; CORS `*` sobre datos públicos. ✅
- **Brute force**: login cuenta dentro del rate-limit (30 POST/min
  por IP, en DB → sobrevive reinicios y workers paralelos). ✅
- **Replay de sesión robada**: caducidad deslizante + TLS. ✅
- **Datos en logs**: el servidor loguea eventos (auth, publish,
  remove, rate-limit) sin bodies ni tokens; `--log-file` con
  rotación 1MB×3. ✅
- **Verificación de contenido**: solución rejugada server-side en
  niveles sin reglas mutantes (simulador Sokoban vanilla con
  overlays). ✅ testeado en E2E.

## Moderación

`SKM_ADMINS=user1,user2` — los admins pueden borrar cualquier
entrada vía `/api/remove` con su Bearer y consultar `/api/stats`.
La publicación con reglas mutantes no verificable queda marcada
`verified=0` en el feed: detectable y retirable por un admin.
