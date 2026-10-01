# Contribuir

## Entorno

- Godot **4.7+** (descarga única, sin instalación).
- Python **3.10+** solo si trabajas el servidor de comunidad
  (stdlib pura, sin `pip install`).

## Ejecutar

```bash
godot --path .            # juego
godot --editor --path .   # editor Godot
```

## Tests (obligatorios en cada PR)

Todo de golpe: `tools/test_all.ps1` / `tools/test_all.sh`
(GODOT=… para indicar el binario). O por suite:

```bash
godot --headless --path . -s res://tests/test_runner.gd      # motor/core
godot --headless --path . -s res://tests/test_ui.gd          # UI + E2E comunidad (necesita python en PATH)
godot --headless --path . -s res://tests/test_e2e.gd         # flujos completos
godot --headless --path . -s res://tests/test_playthrough.gd # niveles jugados
godot --headless --path . -s res://tests/test_rules.gd       # reglas
godot --headless --path . -s res://tools/audit_levels.gd     # auditoría de campaña
python -m py_compile server/community_server.py              # backend
```

Todas deben terminar en `0 failures`. Los tests escriben en
`user://devin_test/` (aislados de tu perfil real) — el E2E de comunidad
levanta el servidor real en un puerto de prueba y usa una DB temporal.

## Convenciones

- GDScript: tabs, `snake_case`, `class_name` para clases referenciadas
  por otras, comentarios solo donde el porqué no es evidente.
- Lógica de juego pura en `scripts/core/` (sin nodos); UI en
  `scripts/ui/` — nada de `get_node` desde core.
- Commits: acotados, mensaje con el motivo (no solo el qué).
- Si añades una regla nueva: `scripts/core/rules/rule_*.gd` +
  `RuleRegistry` + tests en `test_rules.gd`.

## Issues

Incluye: pasos para reproducir, resultado esperado/actual, versión
de Godot, SO, y el código SKM1 del nivel si el bug es de nivel.
