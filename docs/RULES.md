# Reglas implementadas

Referencia completa de reglas mutantes y tiles especiales. Cada regla
es un plugin `SokobanRule` en `scripts/core/rules/` — añadir una =
un archivo + registrarla en `rule_registry.gd`.

## Reglas (id del nivel)

| Regla | id | Descripción |
|---|---|---|
| Hielo | `ice` | Las cajas se deslizan hasta chocar (opción: `player_slide`, tú también patinas) |
| Rotación | `rotate` | El escenario gira 90° cada N turnos |
| Mímica | `mimic` | Las cajas `&` copian tus movimientos (opción: `opposite`, van al revés) |
| Empuje limitado | `push_limit` | Cada caja solo puede empujarse N veces |
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
| Pegamento | `bond` | Cajas adyacentes se mueven en bloque (estilo Sokobond) |
| Regla férrea | `iron` | Sin deshacer: cada empujón es definitivo (estilo Void Stranger) |
| Terremoto | `quake` | Cada N turnos un seísmo desliza todas las cajas un paso; la dirección rota →↓←↑ |
| Mitosis | `mitosis` | Cada N turnos cada caja engendra una copia (con sus flags) en una celda libre, hasta un tope |
| Mareo | `drunk` | Cada paso gira tu dirección 90° (configurable a 180°/270°) |
| Muelle | `spring` | Cada empujón te rebota a la casilla de donde viniste |
| Sillas | `musical` | Cada N turnos las cajas rotan posiciones en anillo |
| Juego de la Vida | `life` | Cada N turnos las cajas viven por Conway: nacen con 3 vecinas, mueren con <2 o >3 |
| Polos opuestos | `repel` | Las cajas en tu fila/columna resbalan un paso lejos de ti cada turno |
| Enlace cuántico | `link` | Empujar una caja de color mueve a todas las del mismo color |
| Espejo | `mirror` | Cada empujón también empuja la caja en la posición reflejada |
| Controles invertidos | `invert` | Cada dirección mueve al contrario |
| Cuenta atrás | `move_limit` | Resuelve en N turnos o menos, o pierdes |
| Amontonar | `blob` | Se gana cuando todas las cajas forman un bloque conexo; los objetivos no cuentan (opción: `per_color`) |
| Cuota | `quota` | Basta con cubrir N objetivos; el resto sobran |
| Regla secreta | — | Oculta la descripción de la regla hasta resolver el nivel |

## Tiles especiales (en el tablero, sin regla activa)

| Tile | Efecto |
|---|---|
| `?` | Pared tímida: solo sólida mientras el jugador la ve |
| `!` | Interruptor: pisar/cubrir activa o desactiva las reglas |
| `o`/`O` | Portales: entras y sales por la pareja (jugador y cajas) |
| `>` `<` `^` `v` | Cintas: arrastran una casilla por turno lo que tengan encima |
| `k`/`K` | Llave/puerta: solo el jugador, consume la llave |
| `x` | Bomba: una caja empujada contra ella explota con ella |
| `1` `2` `3` `4` | Sentido único: solo sales en su dirección (→↓←↑) |
| `b`/`c`/`d` + `B`/`C`/`D` | Cajas y metas de color: cada una resuelve en la suya |
| `a`/`e`/`i` | Caja de color sobre su meta (compuestos) |
| `j`/`l`/`m` | Caja de color sobre meta neutra |
| `h` | Agujero: una caja lo rellena (desaparecen ambos); pisarlo = derrota |
| `f` | Suelo frágil: se rompe al salir, deja agujero |
| `=`/`:` | Raíles: la caja solo empuja a lo largo del eje |
| `W` | Muro débil: un empujón lo demuele (cuesta un turno) |
| `w` | Intercambio: la caja que entra cambia de posición contigo |
| `p` | Multiban: empujadores extra; Espacio cicla el control |
| `E`/`G`/`H` | Filtros de color: solo la caja del color b/c/d atraviesa |
| `q` | Caja rodante: rueda hasta chocar |
| `n` | Caja pesada: descansa un turno tras empujarla |
| `u` | Sumidero: pozo solo para cajas; el jugador lo pisa |
| `z` | Tracción: alejarte de una caja adyacente la arrastra |
| `&` / `%` | Caja mimética / mimética en objetivo |

Extras: **códigos de pack** `SKM2.…` para compartir colecciones
enteras y `SKM1.…` para niveles sueltos (JSON deflado + base64url,
con overlays de ocupante incluidos).
