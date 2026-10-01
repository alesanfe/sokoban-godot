# Sokoban Mutante

Sokoban donde cada nivel introduce una regla absurda. Proyecto **Godot 4.7** (GDScript) · **MIT** · v1.0.0.

📖 [Arquitectura](docs/ARCHITECTURE.md) · [API del backend](docs/API.md) · [ADRs](docs/decisions/) · [Contribuir](CONTRIBUTING.md) · [Seguridad](SECURITY.md) · [Changelog](CHANGELOG.md)

Contenido: **155 niveles clásicos** (pack Microban de David W. Skinner, `levels/microban.sok`, formato XSB estándar) y **81 niveles de campaña** que introducen y combinan cada regla absurda, incluyendo interruptores `!` y reglas secretas.

## Cómo ejecutar

```powershell
godot --path .            # jugar
godot --headless --path . -s res://tests/test_runner.gd      # tests del motor + campaña
godot --headless --path . -s res://tests/test_rules.gd       # tests unitarios por regla
godot --headless --path . -s res://tests/test_ui.gd          # smoke test de UI
godot --headless --path . -s res://tests/test_playthrough.gd # bot que JUEGA niveles reales
godot --headless --path . -s res://tests/test_e2e.gd         # E2E: input real sobre main.tscn
```

Exportación web: `export_presets.cfg` incluye un preset **Web** (HTML5/PWA). Necesitas las export templates (`godot --export-release "Web" export/web/index.html`).

O abre la carpeta en el editor de Godot 4.7+ y pulsa F5.

## Reglas implementadas

| Regla | id | Descripción |
|---|---|---|
| Hielo | `ice` | Las cajas se deslizan hasta chocar (opción: `player_slide`, tú también patinas) |
| Rotación | `rotate` | El escenario gira 90° cada N turnos |
| Mímica | `mimic` | Las cajas `&` copian tus movimientos (opción: `opposite`, van al revés) |
| Empuje limitado | `push_limit` | Cada caja solo puede empujarse N veces |
| Paredes tímidas | (tile `?`) | Solo son sólidas mientras el jugador las ve |
| Interruptores | (tile `!`) | Pisar/cubrir una casilla `!` activa o desactiva las reglas |
| Fantasma | `ghost` | Al reiniciar, tu intento anterior se repite y empuja cajas |
| Intercambio | `swap` | Cada N turnos cajas y objetivos intercambian roles |
| Dos jugadores | `two_players` | El control alterna por turnos (opción: controles invertidos) |
| Arrastre | `pull` | No empujas: al alejarte de una caja adyacente la arrastras |
| Gravedad | `gravity` | Cajas y jugador caen hasta apoyarse en algo sólido |
| Mundo toro | `torus` | Los bordes conectan: salir por un lado entra por el otro |
| Imán | `magnet` | Las cajas se acercan a ti cada turno (opción: `repel` las aleja) |
| Cadena | `chain` | Empujas filas enteras de cajas contiguas a la vez |
| Viento | `wind` | Cada N turnos una ráfaga mueve todas las cajas una casilla |
| Vértigo | `spin` | Tus controles giran 90° cada turno |
| Portales | `portal` + tiles `o`/`O` | Entras por una casilla y sales por su pareja (jugador y cajas). `o`↔`o` y `O`↔`O` son canales independientes |
| Cintas | `conveyor` + tiles `>` `<` `^` `v` | Arrastran una casilla por turno lo que tengan encima |
| Llaves y puertas | tiles `k`/`K` | Coge una llave y abre una puerta (solo el jugador pasa; consume la llave) |
| Bombas | tile `x` | Una caja empujada contra `x` explota y desaparece con ella |
| Sentido único | tiles `1` `2` `3` `4` | Solo puedes salir de la casilla en su dirección (→↓←↑); también vale para cajas |
| Colores | tiles `b`/`c`/`d` + `B`/`C`/`D` | Cada caja de color solo resuelve en el objetivo de su color. Compuestos: `a`/`e`/`i` = caja b/c/d sobre su meta; `j`/`l`/`m` = caja b/c/d sobre meta neutra |
| Agujeros | tile `h` | Una caja rellena el agujero (desaparecen ambos); si pisas uno, pierdes |
| Suelo frágil | tile `f` | Se rompe al salir de él y deja un agujero |
| Raíles | tiles `=`/`:` | Una caja sobre un raíl solo puede empujarse a lo largo de su eje |
| Controles invertidos | `invert` | Cada dirección mueve al contrario (el solver no lo sufre: juega con direcciones reales) |
| Cuenta atrás | `move_limit` | Resuelve en N turnos o menos, o pierdes (estilo «clear condition») |
| Pegamento | `bond` | Cajas adyacentes se mueven en bloque (estilo Sokobond) |
| Muro débil | tile `W` | Un empujón lo demuele: ni caja ni jugador avanzan, pero cuesta un turno |
| Intercambio | tile `w` | La caja que entra intercambia posición contigo |
| Multiban | tile `p` | Empujadores extra; Espacio (o pisarlos) cambia de control en ciclo |
| Filtros de color | tiles `E`/`G`/`H` | Solo la caja del color b/c/d atraviesa el filtro (glisa hasta el otro lado); bloquean al jugador |
| Caja rodante | tile `q` | Al empujarla rueda hasta chocar con algo (hielo intrínseco) |
| Caja pesada | tile `n` | Tras empujarla descansa un turno entero antes de poder moverla |
| Sumidero | tile `u` | Pozo solo para cajas: la hunde para siempre (combina con `quota`); el jugador lo pisa |
| Tracción | tile `z` | Sobre la zona, alejarte de una caja la arrastra detrás de ti |
| Amontonar | `blob` | Se gana cuando todas las cajas forman un bloque conexo (Interlock); los objetivos no cuentan (opción: `per_color`, un bloque por cada color) |
| Cuota | `quota` | Basta con cubrir N objetivos; el resto sobran |
| Regla férrea | `iron` | Sin deshacer: cada empujón es definitivo (estilo Void Stranger) |
| Terremoto | `quake` | Cada N turnos un seísmo desliza todas las cajas un paso; la dirección rota →↓←↑ |
| Mitosis | `mitosis` | Cada N turnos cada caja engendra una copia (con sus flags) en una celda libre, hasta un tope |
| Mareo | `drunk` | Cada paso gira tu dirección 90° (configurable a 180°/270°) |
| Muelle | `spring` | Cada empujón te rebota a la casilla de donde viniste |
| Sillas | `musical` | Cada N turnos las cajas rotan posiciones en anillo |
| Juego de la Vida | `life` | Cada N turnos las cajas viven por Conway: nacen con 3 vecinas, mueren con <2 o >3 |
| Polos opuestos | `repel` | Las cajas en tu fila/columna resbalan un paso lejos de ti cada turno (Velsokomagnet) |
| Enlace cuántico | `link` | Empujar una caja de color mueve a todas las del mismo color |
| Espejo | `mirror` | Cada empujón también empuja la caja en la posición reflejada (eje vertical u horizontal) |

Extras: **regla secreta** (oculta la descripción hasta resolver el nivel) y **códigos de pack** `SKM2.…` para compartir colecciones enteras.

## Presentación (sprites Kenney + overlays procedurales)

- **Sprites**: pack **Kenney Sokoban (CC0)** en `assets/kenney_sokoban/` — suelo `ground_06`, muro `block_06`, cajas `crate_02-05`, caja resuelta `crate_16`, objetivo `environment_03` (tintado por color), jugador `player_05`. Si falta la carpeta, el tablero cae al render procedural completo (fallback automático).
- **Temas UI** (`UiTheme`, equivalente a ThemeGen): Oscuro / Claro / Alto contraste / Daltonismo — ciclo en el menú, persistente. Tema "Daltonismo" usa paleta Okabe–Ito en el tablero también.
- **Legibilidad <1s**: muros con bisel de profundidad, checker de suelo, sombras bajo entidades, objetivos que **pulsan** mientras estén libres, caja resuelta con **✓** además de color, jugador con ojos que miran en la dirección del último movimiento, letras B/C/D en cajas de color.
- **Game feel**: squash al empujar, sacudida suave al denegar (`deny_fx`), anillo de polvo al aterrizar la caja, flashes de portal, confetti al ganar — todo suprimible con *movimiento reducido*.
- **Transiciones**: fundido de 150 ms entre pantallas (equivalente a Godotwind, en código).
- **Toasts** (`Widgets.toast`, equivalente a ProperUI): récord nuevo, progreso guardado al salir, avisos varios.
- **Confirmar reinicio**: opción de reinicio en dos pasos (doble pulsación) en el menú.
- **Foco visible** de teclado/mando vía `focus` stylebox del tema.

## Extras

- **Continuar**: si sales de un nivel sin resolverlo, el menú ofrece reanudar la partida (posición, historial de deshacer y log de movimientos se restauran).
- **Panel de resultado**: medalla (BRONCE→PERFECTO según par), movimientos/empujes/tiempo, insignias "sin deshacer"/"sin reiniciar", compartir solución al portapapeles y siguiente nivel.
- **Asistencia de bloqueos configurable** (menú): OFF / Aviso sonoro / Marcas rojas / Bloquear empujes suicidas.
- **Importar**: además de códigos SKM, la pantalla de importar acepta tableros XSB y XSB-RLE (`4#|# @$.#|3#`) — incluso colecciones multi-nivel separadas por líneas vacías.
- **Solver en segundo plano**: «Pista», «Resolver» y «Verificar» del editor corren en WorkerThreadPool — la interfaz no se congela.
- **Auditoría de campaña** (`tools/audit_levels.gd`): comprueba que los 81 niveles tienen solución y detecta reglas decorativas (la solución óptima también gana con reglas desactivadas).
- **Validación estructural**: símbolos inválidos, conectividad (flood fill), cajas/objetivos en zonas selladas y objetivos en casillas muertas.

## Comunidad (estilo Mario Maker)

- **Publicar** desde el editor: como en Mario Maker, **solo se puede publicar un nivel que tú mismo has superado** en «Probar».
- **Explorar** el catálogo con orden por Recientes / Populares / Más jugadas / Más superadas y **búsqueda** por título o autor.
- Cada ficha lleva miniatura, autor, fecha, ♥ likes, ▶ partidas y ✓ superados (contabilizados al jugar desde la comunidad: ▶ cuenta en el primer movimiento real — ver una repetición no suma; ✓ solo con victoria sin asistir).
- **Like ♥**, **Guardar** en Mis niveles, **⤴ compartir** (copia el código `SKM1.` del nivel al portapapeles — el canal de intercambio real en modo offline) y retirar publicaciones propias.
- Los datos viven en `user://community.json` a través de `CommunityService` — **modo local/offline por defecto**, con un backend autoalojable opcional: `python server/community_server.py --port 8765` (solo stdlib + SQLite) y pegar su URL en el campo «Servidor» de la pantalla Comunidad. Con backend hay **cuentas reales**: registro/login (Bearer token, pbkdf2), publicar y dar like requieren sesión (el like es un toggle por cuenta, sin trampas), borrar exige ser el autor; jugar/superar siguen siendo anónimos. El feed remoto se sincroniza a un espejo local con paginación; sin sesión el modo es solo lectura sobre el feed remoto.
- El catálogo arranca con niveles semilla del "Equipo Sokoban".

## Comodidad y pulido (estilo Parabox / Sokoban++)

- **Aviso de callejones sin salida**: en niveles clásicos, las casillas donde una caja queda muerta para siempre se tintan de rojo, las cajas atrapadas llevan una ✕ y el movimiento que las crea suena con una alarma suave.
- **Rewind**: mantén Z para rebobinar rápido (Y rehace).
- **Repetición interrumpible**: cualquier tecla para la replay/solución y sigues jugando desde ese punto.
- **Migas (T)**: dibuja tu mejor ruta guardada como puntos tenues en el suelo.
- **Juice**: squash-and-stretch al empujar, micro-sacudida, flashes en teletransportes y confetti al ganar (todo desactivable con "Movimiento reducido").
- **Selector con miniaturas**, **buscador** (por título o regla) y botón **"Siguiente sin resolver"**.
- **Cronómetro** por nivel, contador de **empujes** separado y mejor tiempo guardado.
- **Estadísticas**: completados/★/movimientos por pack, tiempo total y **racha de desafíos diarios**.
- **Mapa del mundo** navegable (estilo Isles of Sea and Sky): camina entre nodos de nivel por islas — campaña, clásicos y tus niveles. Entra con Enter o clic.
- **Música ambiental generativa**: pads de acordes + campanas pentatónicas sintetizadas en tiempo real (`AudioStreamGenerator`, sin assets). Toggle y volumen en Opciones.
- **Controles reasignables** desde el menú (las flechas siempre funcionan).

## Personalización

Todo persiste en `user://settings.json` y se agrupa en **Opciones…**:

- **Vídeo**: tema de la interfaz (Oscuro/Claro/Alto contraste/Daltonismo) y **skin del tablero** (Sprites Kenney, Plano procedural, Retro con tinte sepia).
- **Audio**: música on/off, **volumen**, efectos on/off.
- **HUD**: toggles para movimientos, tiempo y par/mejor marca.
- **Jugabilidad**: asistencia de bloqueos (off/aviso/marcas/bloquear), confirmar reinicio, movimiento reducido, **velocidad del autoplay** (0.5×–4×) y **cadencia de repetición** al mantener la tecla.
- **Desafío personalizado**: generador con ancho/alto/nº de cajas/regla/semilla a elegir (menú → «Desafío personalizado…»).
- En el **editor**, los parámetros de regla admiten ints, bools y **selectores** (p.ej. dirección del viento →←↓↑).

## Arquitectura

- `scripts/core/game_state.gd` — motor determinista puro (sin nodos): movimiento, undo por snapshots, log LURD, serialización. Todo lo demás (UI, solver, replays) usa este mismo motor.
- `scripts/core/rules/` — cada regla es un plugin `SokobanRule` con hooks (`can_push`, `resolve_push`, `after_player_move`, `after_turn`, `on_tick`, `state_key`). Añadir una regla = crear un archivo y registrarlo en `rule_registry.gd`.
- `scripts/core/level_data.gd` — XSB extendido (`&` caja mimética, `%` mimética en objetivo, `?` pared tímida, `!` interruptor) + códigos de nivel `SKM1.<len>.<base64url(deflate(json))>` y packs `SKM2.…`.
- `scripts/core/solver.gd` — BFS sobre el motor real con poda por casillas muertas (pull-BFS inverso) para niveles clásicos. También clasifica dificultad (1–5★).
- `scripts/core/generator.gd` — generador procedural: cava la sala con random walk y desordena con pulls inversos (garantiza solubilidad), luego verifica con el solver. `daily()` genera el desafío diario con seed por fecha.
- `scripts/core/storage.gd` — niveles propios, mejores marcas y repeticiones en `user://`.
- `scripts/ui/` — pantallas construidas en código: menú, juego (tablero dibujado con `_draw`), selector con miniaturas, mapa del mundo, editor, importar código.

## Editor de niveles

- Paleta de 46 tiles (paredes, cajas, miméticas, objetivos, tímidas, interruptores, portales, cintas, llaves, puertas, bombas, unidireccionales, cajas/metas de color y sus compuestos sobre meta, agujeros, frágiles, raíles, muros débiles, intercambios, gemelo) con cuentagotas (Alt+clic o clic medio) y zoom ±.
- **Overlays de ocupante**: una caja sellada sobre terreno pisable no expresable (meta de otro color, cinta, portal, interruptor…) no pisa el tile — se guarda como overlay (`LevelData.over`) y viaja en los códigos SKM1.
- Herramientas de forma: **punto, línea, rectángulo y relleno** (flood), con vista previa al arrastrar.
- **Pintura simétrica** (espejo X/Y) y transformaciones de tablero: voltear ↔/↕, rotar ⟳ (las cintas rotan su flecha).
- **Ctrl+Z / Ctrl+Y** deshacer/rehacer (100 pasos).
- **Copiar/Pegar** el tablero como texto desde el portapapeles (importa XSB directamente).
- Overlay **"Muertes"**: marca casillas donde una caja queda bloqueada para siempre.
- Panel de reglas con parámetros, "Probar" (test-play), "Verificar" (solver + dificultad + par), **"Ver solución"** tras verificar, guardado en Mis niveles y exportación por código `SKM1.`/`SKM2.`.

## Controles

Flechas/WASD mover (mantener pulsado repite) · Z deshacer · Y rehacer · R reiniciar · Espacio cambiar de gemelo · T migas (tu mejor ruta) · F1 solución automática · H pista (siguiente movimiento) · V repetición guardada · Esc menú.

Cada nivel muestra su **par** (movimientos óptimos según el solver); al completar se puntúa con ★–★★★.

## Exportar (web)

Con las export templates instaladas (`%APPDATA%\Godot\export_templates\4.7.2.stable`):

```powershell
godot --headless --path . --export-release "Web" export\web\index.html
```

Genera `export/web/` (index.html + wasm + pck) servible desde cualquier host estático. El preset excluye `tests/`, `tools/` y `server/`.

## Backend de comunidad (opcional)

```powershell
python server/community_server.py --port 8765     # stdlib + SQLite
```

Cuentas Bearer (pbkdf2), feed paginado, like por cuenta, rate-limit,
migración automática del JSON legacy. Contrato completo: [docs/API.md](docs/API.md). Config: `server/.env.example`.

## Licencia

MIT — ver [LICENSE](LICENSE).
