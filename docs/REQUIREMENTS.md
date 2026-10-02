# Requisitos — Sokoban Mutante

## Alcance

**Objetivo**: juego de Sokoban donde cada nivel introduce una regla
mutante, con editor integrado, solver y comunidad de niveles propios.

**Usuarios**: jugador · diseñador de niveles · operador del servidor
de comunidad (self-hosted).

**Incluido**: campaña (81) + clásicos (155), 25 reglas con parámetros,
editor completo con validación por solver, generador procedural,
retos diarios, replays/records/medallas, comunidad con cuentas,
likes y feed, import/export SKM1/XSB, accesibilidad.

**No incluido**: multijugador, ranked, chat, moderación de contenidos,
cuenta central gestionada por el proyecto (cada backend es propiedad
de quien lo opera), pagos.

## Requisitos funcionales verificables (muestra con criterios)

**RF-1 Movimiento**: solo empujar, una caja a la vez; toda acción es
reversible. Criterio: fuzz de 500 movimientos aleatorios + undo completo
reproduce el estado inicial — `test_runner.gd`.

**RF-2 Reglas con parámetros**: cada regla se serializa
`{id, params}` y altera el movimiento solo vía `GameState`. Criterio:
`test_rules.gd` prueba activación/parámetro/serialización por regla.

**RF-3 Editor → publicación**: no se puede publicar un nivel sin
superarlo. Criterio: UI bloquea Compartir hasta `is_playtested`;
`test_ui.gd` verifica el gate.

**RF-4 Código SKM1**: `to_code()` → `from_code()` es ida y vuelta
exacta, incluidos overlays y reglas. Criterio: round-trip en
`test_runner.gd` sobre la campaña completa.

**RF-5 Comunidad autenticada**: register/login Bearer; publish fija el
autor desde la sesión; like es toggle por cuenta; remove exige
propiedad. Criterio: E2E real en `test_ui.gd`
(register→publish→sync→dedup→like→remove).

**RF-6 Feed determinista**: orden por timestamp+id, paginación
offset/limit ≤ 200, la publicación propia nunca aparece duplicada.
Criterio: checks de merge + E2E.

## Requisitos no funcionales medibles

| # | Propiedad | Objetivo | Verificación |
|---|---|---|---|
| NFR-1 | Determinismo | mismo estado+input → mismo resultado, en todos los workers | fuzz `test_runner` |
| NFR-2 | Presupuesto solver | ≤60k estados/intento, escalado ×4/×15 documentado | `audit_levels` |
| NFR-3 | Límites API | payload ≤68KB, reglas ≤8, rate-limit 30 POST/min | backend + E2E |
| NFR-4 | Privacidad | token de borrado nunca sale por `/api/feed`; passwords solo pbkdf2 | test + SECURITY.md |
| NFR-5 | Recuperación | `user://` con write atómico `.tmp`+rename y `.bak` | tests storage |
| NFR-6 | Instalación | clonar → `godot --path .` sin pasos no documentados | README |
| NFR-7 | Portabilidad | Windows/Linux/macOS + export Web | `export_presets.cfg` |

## Métricas de éxito (UX)

Sin telemetría (offline-first), pero los mismos datos que `Storage`
persiste en `user://` permiten definir KPIs medibles por sesión o por
herramienta de análisis local. Se calculan sobre:

- `progress.json` → `best` (movimientos/tiempo por nivel), `replays`
- `stats.json` → totales `wins`, `moves`, `pushes`, `undos`,
  `restarts`, `hints`
- `in_progress.json` → existencia de partida pausada
- `community.json` → `plays`, `clears`, `likes` por entrada

| KPI | Definición | Umbral de alerta |
|---|---|---|
| Tasa de completación | `wins / (wins + restarts)` | < 0.3 por nivel = nivel frustrante |
| Abandono | `in_progress.json` con `state.moves` altos y sin `win` | nivel con muchos abandonos = revisar par |
| Eficiencia | `moves / pushes` medio | alejado del par = nivel demasiado suelto |
| Uso de asistencia | `hints / wins` | > 0.5 = campaña demasiado dura |
| Ratio deshacer | `undos / moves` | > 0.2 = input impreciso o regla confusa |
| Replay share | `replays` con ruta vs `wins` | si nadie reutiliza = feature invisible |
| Community funnel | `plays → clears → likes` | conversión baja = niveles publicados pobres |

Estos KPIs no son telemetry externa: es el análisis local de los
datos que el juego ya guarda. Sirven para decidir si un nivel,
una regla o una asistencia funcionan como se esperaba.

## Definición de terminado (DoD)

1. `test_runner` + `test_rules` + `test_playthrough` + `test_e2e` +
   `test_ui` en 0 fallos.
2. `audit_levels` sin regresiones graves de la campaña.
3. Si toca el contrato de comunidad → `docs/API.md` actualizado.
4. Si cambia una decisión → ADR nuevo/modificado.
5. Si es visible al jugador → CHANGELOG.
