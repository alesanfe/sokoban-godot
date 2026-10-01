# ADR-001: Core puro sin nodos, clases estáticas en RefCounted

## Contexto

El juego necesita tests headless rápidos y un solver/generador que
corran en worker threads sin tocar el SceneTree.

## Decisión

Toda la lógica vive en `scripts/core/` como clases `RefCounted` (o
estáticas): `GameState`, `LevelData`, `SokobanSolver`, `Generator`,
`Storage`, `CommunityService`, `RuleRegistry`. La UI los instancia
y les pasa datos; nunca al revés.

## Consecuencias

+ `tests/test_runner.gd` corre 227 checks en segundos sin UI.
+ Workers seguros: el solver muta su propia copia del estado.
+ Las pantallas quedan como orquestación (señales + callbacks).
+ Los singletons estáticos (`Storage.BASE_DIR`) requieren disciplina;
  mitigado con override explícito en tests.
