# AGENTS.md — Sokoban Mutante

## Contexto

Sokoban con mecánicas mutantes en Godot 4. El juego vive en la raíz del
repo (`project.godot`); el servidor de comunidad en `server/` (Python).

## Comandos

```bash
godot --path .                                            # jugar (o F5 en el editor)
godot --headless --path . -s res://tests/test_runner.gd   # checks motor + campaña
godot --headless --path . -s res://tests/test_ui.gd       # UI + comunidad E2E
godot --headless --path . -s res://tests/test_e2e.gd      # E2E

python server/test_routes.py                              # backend sin socket
python server/test_load.py                                # concurrencia

# Capturas de UI
godot --path . -s res://tools/screenshots.gd -- [nombre ...]  # subset opcional
godot --path . -s res://tools/gif_demo.gd                     # GIF de demo
```

## Estructura

```text
project.godot  # proyecto Godot (raíz)
scenes/        # escenas .tscn
scripts/       # GDScript (scripts/ui/ = pantallas, scripts/game/ = motor)
assets/        # recursos
levels/        # niveles de campaña
server/        # servidor de comunidad (Python) + tests
tools/         # screenshots.gd, gif_demo.gd, export, _shots/ (salida)
tests/         # runners GDScript
docs/          # documentación + assets (capturas públicas)
export/        # builds exportadas (gitignored)
```

## Reglas del proyecto

- **Tema**: todo el chrome de UI usa `scripts/ui/ui_theme.gd` (`UiTheme`) —
  variantes dark/light/contrast/color-blind. Los colores del tablero son
  arte de juego y sí pueden ser literales (paleta por tema en
  `BoardView.theme_palette()`).
- **Widgets**: usar `scripts/ui/widgets.gd` (`Widgets.*`) en vez de
  botones/etiquetas ad hoc; `Widgets.set_danger()` para el estado armado
  del patrón doble-clic destructivo.
- **Confirmaciones destructivas**: patrón "pulsa de nuevo para confirmar"
  (texto + `set_danger` 2 s) — igual en editor, comunidad y opciones.
- Los PNGs de `tools/_shots/` son salida de trabajo; los de `docs/assets/screenshots/`
  son los publicados en README.

## Verificación

- Los avisos WASAPI/audio en headless son del entorno, no fallos de UI.
- Tras tocar pantallas: regenerar el subset afectado de `tools/_shots/`
  y comprobar que no salen en blanco (PNG ~4 KB = captura temprana).
