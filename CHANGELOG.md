# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
el proyecto usa [Semantic Versioning](https://semver.org/lang/es/).

## [1.1.0] — 2026-10-01

Backend de comunidad endurecido — se eliminan los límites que la
versión 1.0 documentaba como aceptados.

### Añadido
- **TLS nativo**: `--tls-cert/--tls-key` (PEM, TLS ≥1.2) — https://
  sin proxy obligatorio.
- **Caducidad de sesiones**: `expires` por sesión, `SKM_SESSION_DAYS`
  (30) con renovación deslizante; `401 token_expired` y el cliente
  cierra sesión local solo (auto-logout).
- **Moderación**: `SKM_ADMINS` — admins borran cualquier entrada y
  leen `GET /api/stats` (métricas operativas por proceso + DB).
- **Verificación server-side de soluciones**: `publish` recibe
  `moves` (replay del playtest); el servidor rejuega el Sokoban
  vanilla y devuelve `verified` o `422 unsolved`.
- **Log de seguridad**: eventos (auth/publish/remove/rate-limit) a
  stderr y `--log-file` con rotación 1MB×3.

### Cambiado
- Rate-limit por IP movido a SQLite (`rate` table, `BEGIN
  IMMEDIATE`): compartido entre procesos y persistente.
- `publish` fija el autor desde la sesión y exige sesión válida;
  feed expone `verified` por entrada.

## [1.0.0] — 2026-10-01

Primera versión completa: juego jugable + editor + comunidad.

### Juego
- Motor Sokoban determinista: mover, empujar, deshacer/rehacer,
  reiniciar, replay y guardado de partida en curso.
- 25 reglas mutantes (hielo, portales, gravedad, cadenas, límites de
  empuje, dos jugadores, etc.) con parámetros configurables.
- Campaña de 81 niveles (clásicos + mutantes), retos diarios y
  generador procedural con seed compartible.
- Solver BFS off-thread con escalado de presupuesto, pistas,
  detección de deadlocks y clasificación de par/medallas.
- Estadísticas, récords, medallas (PERFECTO/ORO/PLATA/BRONCE),
  badges y progreso persistente en `user://`.
- Accesibilidad: teclas remapeables, tamaño de tablero, daltonismo
  por símbolos, reduce-motion, alto contraste.

### Editor
- Editor de niveles integrado: pintado, undo/redo, rotación, resize,
  overlays de ocupante (caja sobre objetivo, etc.), reglas con
  parámetros, validación y solver de comprobación.
- Publicación condicionada a superar el propio nivel (playtest gate).
- Importación/exportación: códigos SKM1 (zlib+base64), XSB, packs.

### Comunidad
- Feed local con likes, partidas, superados, búsqueda y ordenación.
- Backend autoalojable (`server/community_server.py`, solo stdlib +
  SQLite): cuentas con Bearer token (pbkdf2), like como toggle por
  cuenta, remove por propiedad, feed paginado, rate-limit por IP,
  códigos de error estables, CORS público, health real.
- Cliente Godot con auth persistente, espejo del feed remoto y
  reconciliación optimista de likes.

### Verificación
- Suite headless: motor (227 checks), UI smoke, E2E, playthroughs,
  reglas, fuzz de determinismo, auditoría de campaña.
- E2E de comunidad contra el servidor real (register → publish →
  sync → like → remove).
- Export Web verificado (HTML5/WASM).

### Infraestructura del repositorio
- LICENSE (MIT), CHANGELOG, CONTRIBUTING, SECURITY, docs/ con
  arquitectura, ADRs y contrato de API.
