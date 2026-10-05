# Release Gate — checklist de QA

Puerta previa a cada tag `v*`. El objetivo no es "cero bugs" sino
una build estable, identificable y recuperable. Cada ítem debe
registrar evidencia (build probado, output de tests, quién decidió).

## Build e identificación

- [ ] `config/version` en `project.godot` coincide con el tag
- [ ] El menú muestra esa versión (verificación visual)
- [ ] `CHANGELOG.md` tiene entrada `[x.y.z]` con fecha
- [ ] Los artefactos de la release llevan sha256 + attestation
      (lo hace `release.yml`; comprobar en la página del release)

## Suites (CI)

- [ ] `test_runner.gd` — 227 checks, 0 failures
- [ ] `test_rules.gd` — reglas por unidad
- [ ] `test_ui.gd` — smoke UI + comunidad E2E
- [ ] `test_playthrough.gd` — bot juega niveles reales
- [ ] `test_e2e.gd` — input real sobre main.tscn
- [ ] `python server/test_routes.py` + `test_load.py` — backend
- [ ] ruff + bandit + gdlint — 0 hallazgos

## Build real exportado (no el editor)

Las guías de QA indie coinciden: **el build exportado no es el
editor** — siempre probar el artefacto final.

- [ ] `dist/sokoban-mutante-windows.zip` arranca en una máquina limpia
      (sin Godot instalado, sin `user://` previo)
- [ ] El icono propio aparece (no el de Godot por defecto)
- [ ] `export/web/index.html` sirve bajo cabeceras COOP/COEP
      (`Cross-Origin-Opener-Policy: same-origin`,
      `Cross-Origin-Embedder-Policy: require-corp`) — itch.io las
      aplica; sin ellas SharedArrayBuffer no existe y la web no carga

## FTUE (primeros 5 minutos — afecta al 100% de jugadores)

- [ ] Instalación limpia → menú arranca
- [ ] Primer nivel de campaña se juega y se gana
- [ ] Salir a mitad de nivel → "Continuar" restaura la partida
- [ ] Crear nivel en el editor → Probar → Publicar pide playtest

## Guardado / progreso

- [ ] Progreso persiste entre ejecuciones
- [ ] Un `progress.json` corrupto no rompe el arranque
      (`.bak` + recuperación de `Storage.save_json` atómica)
- [ ] `settings.json` corrupto cae a defaults

## Comunidad (si hay backend)

- [ ] `python server/community_server.py` arranca y `/api/health`
      responde `{"ok":true}`
- [ ] Publicar un nivel vanilla sin `moves` válidas → `422 unsolved`
- [ ] Like por cuenta funciona como toggle

## Regresiones y decisión

- [ ] Bugs críticos conocidos: lista con decisión explícita
      (bloquea / se shippea documentado en release notes)
- [ ] Las release notes no exponen rutas internas ni credenciales
- [ ] Rollback: tag anterior sigue disponible; el `user://` del
      jugador es compatible con la versión anterior (sin migración
      destructiva)

## Publicación

- [ ] itch.io: canales `windows`/`linux`/`web` reciben la build
      (butler job, `ITCH_DEPLOY=1` + `BUTLER_API_KEY` en secrets)
- [ ] Página de itch: descripción, tags, capturas actualizadas
      (`docs/assets/*.png` se regeneran con `tools/screenshots.gd`)
- [ ] Versión de Godot pinneada (`.godot-version`) coincide con la
      de CI
