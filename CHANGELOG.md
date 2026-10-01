# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/);
el proyecto usa [Semantic Versioning](https://semver.org/lang/es/).

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
