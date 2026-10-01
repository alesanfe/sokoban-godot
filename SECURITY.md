# Política de seguridad

## Alcance

- **Juego (Godot)**: proceso local; los datos del jugador viven en
  `user://`. No trata credenciales salvo el token de la comunidad.
- **Backend de comunidad** (`server/community_server.py`): servicio
  autoalojado pensado para LAN o detrás de un proxy con TLS.
  No es un servicio público gestionado.

## Reportar una vulnerabilidad

Abre un issue **sin** datos sensibles, o contacta al mantenedor del
repositorio si el fallo permite tomar el servidor o leer datos de
otros usuarios. Incluye: endpoint, payload, resultado y versión.

## Lo que ya está cubierto (y verificado por tests/E2E)

- Passwords: `pbkdf2_sha256` 100k + salt por usuario.
- Auth Bearer en publish/like/remove; el autor lo fija el servidor.
- Like = toggle por cuenta (PK compuesta, sin multi-like).
- Rate-limit 30 POST/min por IP; payloads ≤ 68 KB; consultas
  parametrizadas; token de borrado nunca sale por `/api/feed`.
- Login sin enumeración (misma respuesta para user inexistente).
- `nosniff`, CORS `*` documentado (feed público, sin cookies).

## Controles adicionales implementados

- TLS nativo: `--tls-cert/--tls-key` (o `SKM_TLS_CERT/KEY`) — https://
  directo sin proxy; también funciona detrás de Caddy/nginx.
- Sesiones con caducidad (`SKM_SESSION_DAYS`, 30 por defecto,
  renovación deslizante); el cliente cierra sesión local solo al
  recibir 401.
- Moderación: `SKM_ADMINS` da a esas cuentas borrado de cualquier
  entrada y acceso a `/api/stats` (métricas operativas).
- Prueba de solución server-side: `publish` exige `moves` y rejuega
  la solución en niveles vanilla (`422 unsolved` si no resuelve);
  los niveles con reglas mutantes salen `verified=0` y son
  moderables.
- Rate-limit persistido en SQLite (válido entre procesos y tras
  reinicios).
- Log de seguridad rotado (`--log-file`): auth fallidos, publish,
  remove, rate-limits — sin bodies ni tokens.
