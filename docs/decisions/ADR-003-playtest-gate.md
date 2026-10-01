# ADR-003: Publicar exige superar el propio nivel — gate doble

## Contexto

Un feed de comunidad donde cualquiera publica sin comprobar se llena
de niveles imposibles o triviales. El gate era solo client-side: un
cliente modificado podía falsificarlo.

## Decisión

Gate en dos capas:

1. **Cliente**: publicar exige `Storage.is_playtested(id)` — el nivel
   se gana una vez desde el editor; el solver verifica además que
   existe solución.
2. **Servidor**: `publish` recibe `moves` (el replay del playtest) y
   los **rejuega en servidor** con un simulador Sokoban vanilla
   (incluye overlays de ocupante). Si el replay no cierra el tablero:
   `422 unsolved`. Niveles con reglas mutantes se aceptan con
   `verified=0` (el servidor no reimplementa el motor de reglas).

## Consecuencias

+ Los niveles vanilla del feed están probados por el servidor —
  el cliente ya no es el único garante.
+ `verified` es visible en el feed y permite filtrar/moderar.
- La verificación de mutantes es trust-but-verify: reputación +
  moderación admin. Reimplementar el motor de reglas en Python
  duplicaría ~2000 líneas que pueden divergir — peor deuda que el
  trust model. Documentado en ADR-006.
