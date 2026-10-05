# Sokoban Mutante

Sokoban donde cada nivel introduce una regla absurda — con editor de niveles,
solver, campaña de 81 niveles mutantes + 155 clásicos Microban, y un
Modo Comunidad estilo Mario Maker con backend autoalojable.

[![CI](https://github.com/alesanfe/sokoban-godot/actions/workflows/ci.yml/badge.svg)](https://github.com/alesanfe/sokoban-godot/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/alesanfe/sokoban-godot)](https://github.com/alesanfe/sokoban-godot/releases)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)
![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478cbf)

📖 [Arquitectura](docs/ARCHITECTURE.md) ·
[Reglas](docs/RULES.md) ·
[API](docs/API.md) ·
[Operación](docs/OPERATIONS.md) ·
[Contribuir](CONTRIBUTING.md) ·
[Seguridad](SECURITY.md) ·
[Changelog](CHANGELOG.md)

## Galería

<p align="center">
  <img src="docs/assets/demo.gif" alt="Partida autojugada: el jugador empuja dos cajas sobre sus metas y el panel de victoria muestra movimientos y empujes" width="640">
</p>

<table>
  <tr>
    <td><img src="docs/assets/screenshots/gameplay.png" alt="Nivel con cintas, portales y cajas de color en juego"></td>
    <td><img src="docs/assets/screenshots/mutant.png" alt="Nivel de campaña con regla fantasma"></td>
  </tr>
  <tr>
    <td><img src="docs/assets/screenshots/editor.png" alt="Editor de niveles con paleta de 46 tiles"></td>
    <td><img src="docs/assets/screenshots/community.png" alt="Modo Comunidad con feed, likes y miniaturas"></td>
  </tr>
</table>

<details>
<summary>Más capturas — selector, mapa, comunidad, ajustes y herramientas</summary>

| Selector de niveles | Asistencia anti-deadlock |
|---|---|
| ![Selector de niveles con progreso por pack](docs/assets/screenshots/select.png) | ![Casillas sin retorno sombreadas y ✕ sobre la caja bloqueada](docs/assets/screenshots/deadlock.png) |

| Panel de victoria | Importador |
|---|---|
| ![Panel de victoria: medalla, movimientos, empujes y par](docs/assets/screenshots/win.png) | ![Importar código SKM o tablero XSB](docs/assets/screenshots/import.png) |

| Mapa de mundo | Generador |
|---|---|
| ![Mapa de mundo: camino por la campaña](docs/assets/screenshots/map.png) | ![Generador de niveles con semilla y regla](docs/assets/screenshots/generator.png) |

| Pista del solucionador | Mejor ruta |
|---|---|
| ![Flecha de pista del solver sobre el jugador](docs/assets/screenshots/hint.png) | ![Ruta en L de puntos de la mejor repetición guardada](docs/assets/screenshots/trail.png) |

| Estadísticas | Opciones | Controles |
|---|---|---|
| ![Estadísticas: campaña, clásicos, diarios, actividad](docs/assets/screenshots/stats.png) | ![Opciones: tema, skin, audio, HUD, asistencias](docs/assets/screenshots/options.png) | ![Controles reasignables](docs/assets/screenshots/controls.png) |

|| Menú principal ||
||---|---|
|| ![Menú principal: campaña, mapa del mundo, desafío diario, editor, comunidad](docs/assets/screenshots/menu.png) | |

</details>

<details>
<summary>Estados de la interfaz — la suite de capturas cubre también los casos límite</summary>

| Estado | Captura |
|---|---|
| Confirmación destructiva (doble clic, botón armado) | ![Controles con 'Pulsa de nuevo para confirmar' armado](docs/assets/screenshots/state_confirm.png) |
| Foco de teclado visible | ![Menú con foco en 'Editor de niveles'](docs/assets/screenshots/state_focus.png) |
| Búsqueda sin resultados | ![Comunidad: 'Sin resultados para «xyzqq»'](docs/assets/screenshots/state_empty.png) |
| Error de validación | ![Importador: 'Código o tablero inválido'](docs/assets/screenshots/state_import_err.png) |
| Texto largo | ![Selector: título de nivel muy largo en 'Mis niveles'](docs/assets/screenshots/state_longtext.png) |
| Cambios sin guardar | ![Editor: 'Tienes cambios sin guardar' antes de salir](docs/assets/screenshots/state_unsaved.png) |
| Gate de publicación | ![Editor: 'Para publicar debes superar tu propio nivel'](docs/assets/screenshots/state_publish_gate.png) |
| Verificación con solver | ![Editor: 'Soluble en 3 movimientos. Dificultad: ★'](docs/assets/screenshots/state_verify.png) |
| Solver buscando | ![Partida: 'Buscando solución…'](docs/assets/screenshots/state_solve.png) |
| Repetición | ![Modo repetición de la mejor solución](docs/assets/screenshots/state_replay.png) |
| Toast de confirmación | ![Comunidad: toast '✓ Guardado en Mis niveles'](docs/assets/screenshots/state_toast.png) |
| Tablero grande en editor | ![Editor con nivel de 30×18 casillas](docs/assets/screenshots/state_editor_big.png) |
| Juego (estado de tabulación) | ![Partida con cajas coloreadas B/C y cintas](docs/assets/screenshots/state_tab_game.png) |
| Selector (estado de tabulación) | ![Selector de niveles con scroll](docs/assets/screenshots/state_tab_select.png) |
| Editor (estado de tabulación) | ![Editor con reglas Cintas y Portales configuradas](docs/assets/screenshots/state_tab_editor.png) |

</details>

<details>
<summary>Temas y accesibilidad — dark (defecto), light, contraste, daltonismo y escala 130%</summary>

| Pantalla | Light | Contraste | Daltonismo |
|---|---|---|---|
| Menú | ![Menú en tema claro](docs/assets/screenshots/theme_menu_light.png) | ![Menú en alto contraste](docs/assets/screenshots/theme_menu_contrast.png) | ![Menú en paleta para daltonismo](docs/assets/screenshots/theme_menu_cb.png) |
| Partida | ![Partida en tema claro](docs/assets/screenshots/theme_gameplay_light.png) | ![Partida en alto contraste](docs/assets/screenshots/theme_gameplay_contrast.png) | ![Partida en paleta para daltonismo](docs/assets/screenshots/theme_gameplay_cb.png) |
| Editor | ![Editor en tema claro](docs/assets/screenshots/theme_editor_light.png) | ![Editor en alto contraste](docs/assets/screenshots/theme_editor_contrast.png) | ![Editor en paleta para daltonismo](docs/assets/screenshots/theme_editor_cb.png) |
| Selector | ![Selector en tema claro](docs/assets/screenshots/theme_select_light.png) | ![Selector en alto contraste](docs/assets/screenshots/theme_select_contrast.png) | ![Selector en paleta para daltonismo](docs/assets/screenshots/theme_select_cb.png) |
| Comunidad | ![Comunidad en tema claro](docs/assets/screenshots/theme_community_light.png) | ![Comunidad en alto contraste](docs/assets/screenshots/theme_community_contrast.png) | ![Comunidad en paleta para daltonismo](docs/assets/screenshots/theme_community_cb.png) |

| Escala de texto 130% | |
|---|---|
| ![Menú con escala de UI al 130%](docs/assets/screenshots/theme_menu_scale130.png) | ![Opciones con escala de UI al 130%](docs/assets/screenshots/theme_options_scale130.png) |

</details>

*Las capturas se regeneran con `godot --path . -s res://tools/screenshots.gd`
y el GIF con `godot --path . -s res://tools/gif_demo.gd` +
`python tools/make_gif.py`.*

## Para el jugador

| | |
|---|---|
| **Jugar ya** | `godot --path .` o abre el proyecto en el editor y pulsa **F5** |
| **Desafío diario** | nivel nuevo cada día, con racha |
| **Compartir** | código `SKM1.…` al portapapeles — funciona sin internet |
| **Editor** | 46 tiles, Ctrl+Z/Y, "Probar" y "Verificar" con solver en worker |

## Para el que mira el código

| | |
|---|---|
| **Motor puro** | `RefCounted`, sin SceneTree — 227 checks headless en segundos |
| **Reglas = plugins** | un archivo por regla, hooks declarativos |
| **Backend opcional** | Python stdlib + SQLite WAL, self-hosted |
| **Un comando lo verifica** | `tools/test_all.ps1` — motor + UI + backend + lint |

## Inicio rápido

**Jugar sin compilar**: descarga la build de tu plataforma en
[Releases](https://github.com/alesanfe/sokoban-godot/releases)
(Windows, Linux o web jugable en el navegador).

```bash
git clone https://github.com/alesanfe/sokoban-godot.git
cd sokoban-godot
godot --path .            # jugar (o F5 en el editor)
```

Para contribuir:

```bash
tools/test_all.ps1        # Windows — todas las suites + backend
tools/test_all.sh         # bash equivalente
```

**Salida esperada**: `== 227 checks, 0 failures ==` y `== UI smoke: 0 failures ==`.

## Qué lo hace mutante

Cada regla es un `SokobanRule` con hooks (`can_push`, `resolve_push`,
`after_player_move`, `on_tick`…) — y cada nivel puede combinarlas con
parámetros del editor:

- **Espacio**: gravedad, toro, portales, cintas, viento, terremoto
- **Tiempo**: rotación del tablero, sillas musicales, Juego de la Vida
- **Cajas**: mímicas, rodantes, pesadas, de color, cadena, mitosis
- **Jugador**: vértigo, controles invertidos, arrastre, muelle, dos jugadores
- **Puerta de atrás**: interruptores `!`, paredes tímidas `?`, bombas `x`,
  llaves, raíles, sumideros, filtros de color — 46 tiles especiales

📚 **Referencia completa**: [docs/RULES.md](docs/RULES.md)

## Contenido

- **81 niveles de campaña** que introducen y combinan cada regla
- **155 niveles clásicos** del pack Microban (formato XSB)
- **Desafío diario** con seed por fecha — mismo nivel para todos
- **Editor integrado** con test-play, solver, dificultad y exportación SKM
- **Modo Comunidad**: publica solo lo que tú mismo has superado;
  backend autoalojable con cuentas Bearer, feed paginado y moderación

## Arquitectura

```mermaid
flowchart TB
    subgraph Godot[Godot 4.7 — client]
        UI[scripts/ui/*<br/>pantallas en código]
        Core[scripts/core/<br/>motor puro RefCounted]
        Rules[scripts/core/rules/<br/>plugins SokobanRule]
        UI --> Core
        Core --> Rules
    end
    subgraph Local[Persistencia local]
        Storage[Storage<br/>user:// JSON atómico]
        Community[CommunityService<br/>catálogo + espejo]
    end
    subgraph Remote[Backend opcional]
        API[server/community/<br/>stdlib + SQLite WAL]
    end
    Core --> Storage
    UI --> Community
    Community -->|REST Bearer| API
```

El motor nunca toca SceneTree — el solver y el generador corren en
`WorkerThreadPool` sin congelar la UI. Reglas y niveles serializan a
JSON; los códigos `SKM1`/`SKM2` son texto portable.

Detalles: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ·
decisiones: [docs/decisions/](docs/decisions/)

## Testing

```bash
godot --headless --path . -s res://tests/test_runner.gd   # 227 checks motor+campaña
godot --headless --path . -s res://tests/test_ui.gd       # UI + comunidad E2E
python server/test_routes.py                              # backend sin socket
python server/test_load.py                                # 250 reqs concurrencia
python -m ruff check server/                              # lint Python
python -m bandit -r server/                               # seguridad Python
```

`tools/test_all.ps1` corre todo lo anterior y gdlint.

## Requisitos

| Para | Necesitas |
|---|---|
| Jugar | Godot 4.7+ (sin Steam — binario único) |
| Contribuir | Python 3.10+, ruff/bandit opcional |
| Backend | Python 3.10+ — cero dependencias externas |

## Estructura

```text
sokoban-godot/
├── scripts/core/      motor determinista, reglas, solver, storage
├── scripts/ui/        pantallas construidas en código
├── server/community/  backend (paquete: config·store·auth·routes…)
├── tests/             runners headless — todo sin SceneTree
├── docs/              requisitos, arquitectura, API, ADRs, operación
└── tools/             test_all, audit_levels, release
```

## Estado del proyecto

> [!NOTE]
> **v1.1.0** — estable y jugable. El backend de comunidad es
> self-hosted (LAN/amigos); no hay instancia pública central.

## Solución de problemas

**La build web no carga en el navegador** — necesita cabeceras
`Cross-Origin-Opener-Policy: same-origin` y
`Cross-Origin-Embedder: require-corp` (SharedArrayBuffer). itch.io
las aplica automáticamente; si la sirves a mano, añádelas.

**El progreso/settings no arranca tras un corte** — `user://` cae al
`.bak` de la última escritura buena (Storage escribe atómico). Si
corrompiste ambos a mano, borra el JSON y vuelve a empezar.

**La comunidad remota no conecta** — comprueba que `community_server.py`
corre y que la URL en Ajustes → Comunidad incluye el puerto.

## Hoja de ruta

- [x] Motor determinista + 30 reglas mutantes
- [x] Editor integrado con test-play y solver
- [x] Campaña + pack clásico + desafío diario
- [x] Modo Comunidad local + backend autoalojable
- [ ] Builds firmadas (Windows/macOS) — requiere certificados
- [ ] Instancia pública de comunidad — requiere hosting
- [ ] i18n completo — hoy la UI está en español

## Limitaciones conocidas

- **UI solo en español** — las strings no pasan por `tr()`; i18n es
  trabajo futuro, no un toggle.
- **Backend sin instancia pública** — el modo Comunidad funciona en
  local; para compartir online hay que autoalojar.
- **Verificación server-side solo en vanilla** — los niveles con
  reglas mutantes publican con `verified=0` y dependen de moderación
  admin (ver ADR-006).
- **macOS sin firma** — el preset existe pero sin notarizar; Gatekeeper
  pedirá saltar la advertencia.
- **Replay/guardado = misma versión** — los replays guardados no están
  garantizados entre versiones del motor (el schema `v` lo rompe a
  propósito, no lo esconde).

## Documentación

| Para | Doc |
|---|---|
| Jugar / instalar | este README |
| Reglas y tiles | [docs/RULES.md](docs/RULES.md) |
| Arquitectura + decisiones | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/decisions/](docs/decisions/) |
| API del backend | [docs/API.md](docs/API.md) |
| Autoalojar el backend | [docs/OPERATIONS.md](docs/OPERATIONS.md) |
| Gate de release | [docs/operations/release-checklist.md](docs/operations/release-checklist.md) |
| Modelo de datos | [docs/DATA_MODEL.md](docs/DATA_MODEL.md) |
| Amenazas / privacidad | [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) · [docs/PRIVACY.md](docs/PRIVACY.md) |

## Contribución

[CONTRIBUTING.md](CONTRIBUTING.md) — `tools/test_all.ps1` es la puerta;
los PRs pasan `ci.yml` (motor + UI + backend + lint + docs).

## Soporte

- Bugs → [issues](https://github.com/alesanfe/sokoban-godot/issues)
- Seguridad → [SECURITY.md](SECURITY.md) (privado, no issue público)
- Canales y datos útiles para reportar → [SUPPORT.md](SUPPORT.md)

## Autores y mantenimiento

Mantenido por [@alesanfe](https://github.com/alesanfe).
Las capturas se regeneran con `tools/screenshots.gd` y las decisiones
grandes se registran como ADRs — la doc se revisa en cada release.

## Reconocimientos

- Sprites [Kenney Sokoban](https://kenney.nl) — CC0.
- Nivel pack clásico Microban © David W. Skinner.
- Inspiration: las variantes de Sokoban de la escena (SokoBond,
  Sokobond, Patrick's Parabox) — el diseño es original.

## Licencia

[MIT](LICENSE) para el código. Los assets de Kenney son CC0;
el pack Microban se usa con atribución a su autor.
