# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
el proyecto usa [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

- Icono propio (`game_icon.png`) — deja de usar el genérico de Godot;
  se aplica al proyecto, al preset web (PWA) y al ejecutable Windows.
- Presets de exportación **Windows Desktop** y **Linux/X11**
  además del web.
- `release.yml` multi-plataforma (matriz web/windows/linux) con
  sha256 + attestation SLSA por artefacto y despliegue a itch.io
  opcional vía butler (`ITCH_DEPLOY=1` + `BUTLER_API_KEY`).
- Versión del build visible en el menú principal
  (`config/version` de `project.godot`).
- `docs/operations/release-checklist.md` — puerta de QA por tag:
  FTUE, guardado, build exportado real, COOP/COEP, regresiones.
- `.godot-version` pinnado para CI.
- `tools/screenshots.gd` — regenera las capturas de `docs/assets/`
  ejecutando las pantallas reales del juego.
- README reestructurado como portada (audiencias, galería, quickstart
  verificable, diagrama Mermaid, docs por Diátaxis) y `docs/RULES.md`
  recoge la referencia completa de reglas/tiles.
- Backend refactorizado a paquete `server/community/` (capas
  config/store/auth/verify/routes/http_api/app), handlers puros
  testeables sin socket (`server/test_routes.py`), socket timeout
  anti-slowloris, escritura atómica con `.bak` en `Storage`.

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
- `POST /api/delete_user` (admin): borra cuenta, sesiones, likes y
  entradas del usuario — último límite operativo eliminado.
- Lint obligatorio: `ruff` + `bandit` + `gdlint` (política en
  `gdlintrc`) en CI y `tools/test_all`; código a 0 hallazgos.
- `server/test_load.py`: 250 reqs concurrentes, consistencia de
  likes y p95 — descubrió la race del toggle de like (`BEGIN
  IMMEDIATE`).
- CI: gitleaks + load test; `release.yml`: export web + SHA256 +
  SBOM CycloneDX + attestation SLSA; `dependabot.yml` +
  `scorecard.yml` (OpenSSF).
- Docs: `docs/operations/slo.md`, `docs/operations/incidents.md`,
  `docs/DATA_MODEL.md`, `docs/PRIVACY.md`, `DEPENDENCIES.md`,
  `.editorconfig`, `.gitattributes`, `tools/test_all.{ps1,sh}`.

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
