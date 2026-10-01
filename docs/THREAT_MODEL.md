# Modelo de amenazas — backend de comunidad

Scope: `server/community_server.py` self-hosted (LAN/amigos o detrás
de proxy TLS). El juego Godot es local y fuera de scope salvo el token.

## Activos

| Activo | Amenaza |
|---|---|
| Passwords | robo de DB → pbkdf2 100k+salt (mitigado) |
| Tokens Bearer | robo en tránsito → TLS vía proxy (responsabilidad del operador); token nunca en feed |
| Identidad del autor | suplantación → el servidor fija `author` desde la sesión, el campo del body se ignora |
| Feed | DoS por spam → rate-limit 30/min IP, payload ≤68KB, MAX_ENTRIES cap |
| Borrado | remove ajeno → Bearer del propietario o token legacy no expuesto |
| Likes | multi-voto → PK (entry_id,user), toggle real |

## Vectores considerados y estado

- **Inyección SQL**: todas las consultas parametrizadas. ✅
- **User enumeration**: login devuelve la misma respuesta para
  usuario inexistente y password incorrecto. ✅
- **Replay/CSRF**: sin cookies → CSRF no aplica; CORS `*` documentado
  porque el feed es público por diseño. ✅
- **Brute force de passwords**: rate-limit por IP cubre `/api/login`
  (cuenta como POST). Proporcional al scope.
- **Path traversal**: sin acceso a ficheros por request; `--db` es
  argumento del operador, no del cliente. ✅
- **Datos sensibles en logs**: el servidor no loguea bodies; los
  tokens no aparecen en respuestas de feed. ✅

## Riesgos aceptados (documentados, no ignorados)

- Gate "supera tu nivel" es client-side: un cliente modificado puede
  publicar sin jugarlo. Aceptado — adversario improbable en
  self-hosted; un servidor público necesitaría solver server-side.
- Sin expiración de sesiones: token Bearer válido hasta borrado de
  `sessions`. Acceptable para LAN; para internet añadir TTL.
- Sin moderación: cualquier cuenta puede publicar. Roadmap abierto.
