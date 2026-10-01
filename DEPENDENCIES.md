# Dependencias

El proyecto es deliberadamente **cero-dependencias** de ejecución:
Godot 4.7 lleva GDScript integrado y el backend usa solo la stdlib
de Python. No hay `requirements.txt` porque no hay nada que
`pip install`e — esto es una decisión (ADR-004), no un vacío.

## Herramientas de desarrollo/build

| Herramienta | Versión | Para qué | Licencia |
|---|---|---|---|
| Godot Engine | 4.7.2 stable | juego + tests headless + export | MIT |
| Python | ≥3.10 | servidor de comunidad (stdlib) | PSF |
| Export templates | 4.7.2 | build Web (HTML5/WASM) | MIT |
| ruff | 0.16.* | linter Python (CI/dev) | MIT |
| bandit | latest | análisis de seguridad Python (CI/dev) | Apache-2.0 |
| gdtoolkit | 4.* | gdlint (GDScript) en CI/dev | MIT |

## Assets

| Asset | Fuente | Licencia |
|---|---|---|
| `assets/kenney_sokoban/` | Kenney Sokoban pack | CC0 (`License.txt` incluido) |
| `levels/microban.sok` | Microban, David W. Skinner | libre uso (permitido por autor) |
| Sonidos/música | generados por código (`music.gd`, `sfx.gd`) | propios |

## Fuentes de paquetes

- Godot: godotengine.org / winget `GodotEngine.GodotEngine`.
- Python: python.org — ninguna dependencia PyPI.

## Política de actualización

- Godot/Python se fijan por versión concreta en CI (`.github/workflows`).
- Si se añade una dependencia real un día: lockfile + revisión de
  licencia + análisis de vulnerabilidades antes del merge.
