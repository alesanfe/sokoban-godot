# Gobernanza — Sokoban Mutante

## Roles

- **Mantenedor**: revisa PRs, decide niveles que entran al catálogo,
  corta releases, administra el servidor de comunidad.
- **Contribuidor**: issues, PRs, niveles vía la comunidad in-game.

## Proceso de cambios

- PR con CI verde (`ci.yml`, `security.yml`, `scorecard.yml`).
- Nivel nuevo al catálogo: obligatorio pasar `make verify` — el
  solver es la puerta (ADR-003), sin excepciones.
- Regla mutante nueva: test en `test_rules.gd` + entrada en
  `docs/RULES.md`.
- ADR en `docs/decisions/` para decisiones arquitectónicas — no se
  borran, se marcan *Superseded*.

## Comunidad

- Niveles publicados: revisables por `SKM_ADMINS`; el servidor rate-
  limita y valida formato antes de aceptar.
- El leaderboard se modera desde el servidor, no desde el cliente.

## Releases

- `release.yml` empaqueta web/windows/linux desde
  `export_presets.cfg`. Las capturas de `docs/assets/screenshots/`
  se regeneran con `make shots` antes de publicar.
