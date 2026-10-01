# ADR-003: Publicar exige superar el propio nivel

## Contexto

Un feed de comunidad donde cualquiera publica sin comprobar se llena
de niveles imposibles o triviales.

## Decisión

La publicación (local o remota) exige `Storage.is_playtested(id)` —
el nivel debe ganarse una vez desde el editor. El solver verifica
además que existe solución.

## Consecuencias

+ Garantía empírica: todo lo del feed es superable.
+ El gate es client-side (el juego local es el garante); el servidor
  solo valida shape — documentado en SECURITY.md.
- Un cliente modificado podría falsificar el gate; aceptado para
  self-hosted (los fans de Sokoban no son un adversario hostil).
