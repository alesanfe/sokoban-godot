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

## Límites conocidos

- Sin TLS propio — despliega detrás de un proxy con HTTPS.
- Sin moderación ni borrado masivo por admin — cualquiera con cuenta
  puede publicar. Para una comunidad pública hace falta un panel de
  moderación (roadmap abierto).
