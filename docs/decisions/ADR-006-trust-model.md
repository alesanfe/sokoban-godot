# ADR-006: Modelo de confianza del feed — verificación parcial

## Contexto

El servidor valida payload, autoría y soluciones, pero el motor de
reglas mutantes vive en GDScript: rejugar un nivel con `ice` o
`portals` en Python exigiría reimplementar ~25 handlers.

## Decisión

- **Niveles vanilla**: el servidor rejuega `moves` → `verified=1`
  o rechazo `422 unsolved`.
- **Niveles con reglas**: se aceptan con `verified=0`; el playtest
  local + reputación de autor + moderación admin (`remove`,
  `delete_user`) son el control.
- El feed expone `verified` para que jugadores y admins filtren.

## Alternativas

- Reimplementar el motor en Python: duplicación divergente garantizada
  — cada regla nueva exigiría mantener dos implementaciones.
- Godot headless en el servidor: convierte un servicio de stdlib en
  una dependencia de 40 MB con runtime de engine — desproporcionado.

## Consecuencias

+ La garantía fuerte cubre el caso común (vanilla es la mayoría).
+ Las mutantes siguen siendo superables por diseño: el editor exige
  playtest antes de permitir el publish local/remoto.
- Un cliente malicioso puede publicar una mutante irresoluble con
  `verified=0` — el flag lo hace visible y la moderación la elimina.
