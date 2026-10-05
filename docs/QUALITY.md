# Calidad — Sokoban Mutante

## Barras de calidad

| Dimensión | Estándar | Verificación |
|---|---|---|
| Motor | Reglas correctas, core puro sin SceneTree | `make test-runner`, `test-rules` |
| Niveles | Todo nivel del catálogo es resoluble | `make verify` (solver gate, ADR-003) |
| UI | Usable en 640×480→retrato; targets ≥44px | `make shots` + revisión visual |
| Temas | Legible en dark/light/contrast/CB | tokens `UiTheme` en todo el chrome |
| Comunidad | Rate-limit, auth, anti-spoofing | `test-server`, `test-load` |
| i18n | Sin literales en UI | revisión + capturas |

## Reglas del código

- `scripts/core/` nunca instancia nodos ni lee la escena — la UI le
  pasa datos (ADR-001).
- Colores de chrome siempre por `UiTheme` (paneles, textos,
  feedback); los colores del tablero/sprites son arte de juego.
- Acciones destructivas: doble-clic con `Widgets.set_danger` +
  texto de confirmación (editor, comunidad, opciones).
- Todo nivel nuevo al catálogo pasa el solver antes de commitear.
