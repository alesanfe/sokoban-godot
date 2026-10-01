# ADR-007: Modelo de sincronía — catálogo local como fuente de verdad

## Contexto

La comunidad debe funcionar offline-first: jugar sin red, y que la
comunidad remota sea un espejo, no una dependencia.

## Decisión

- `community.json` (local) es la fuente de verdad para la UI: las
  entradas remotas se **espejan** con `remote_id`/`source="remote"`.
- La propia publicación se deduplica: al publicar se guarda el
  `remote_id` en la entrada local; el feed no la devuelve otra vez.
- `pull_feed` es refresh completo paginado — el merge es por `id`.
- `like` reconcilia con el valor del servidor (`liked`, `likes`) —
  el conteo real es del servidor, el local se sobrescribe.
- Progreso y récords se indexan por `content_code` (board+rules):
  renombrar un nivel no huerfana su historial.

## Consecuencias

- Juego completo sin servidor; remota es additive.
- Sin estado de conflicto: los contadores los manda el servidor.

- Pull completo escala hasta el orden de miles de entradas —
  suficiente para `MAX_ENTRIES` (5000); más allá haría falta sync
  incremental, fuera del volumen objetivo (ADR-004).
