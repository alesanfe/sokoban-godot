# Soporte

| Qué necesitas | Dónde |
|---|---|
| Reportar un bug | [Issues](https://github.com/alesanfe/sokoban-godot/issues) — incluye la versión del build (menú, esquina inferior) y pasos para reproducir |
| Proponer una regla/feature | Issue con plantilla "Feature request" |
| Duda de uso | Issue etiqueta `question` |
| Vulnerabilidad de seguridad | **No** abras issue público — ver [SECURITY.md](SECURITY.md) |
| Autoalojar el backend | [docs/OPERATIONS.md](docs/OPERATIONS.md) |

## Antes de reportar

- La versión está en el menú principal (abajo) y en
  `config/version` de `project.godot`.
- Guardados/settings viven en `user://` del SO
  (`%APPDATA%\Godot\app_userdata\Sokoban Mutante` en Windows).
- Los logs del juego van a stderr — en Windows arranca la build
  console wrapper para verlos.
