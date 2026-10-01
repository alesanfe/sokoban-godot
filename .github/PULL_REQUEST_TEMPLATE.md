## Qué cambia y por qué

<!-- motivo, no solo el diff -->

## Cómo se ha verificado

- [ ] `test_runner` (motor) — 0 failures
- [ ] `test_ui` — 0 failures
- [ ] `test_e2e` — 0 failures
- [ ] `test_playthrough` — 0 failures
- [ ] `test_rules` — 0 failures
- [ ] `audit_levels` — sin graves nuevos
- [ ] `python -m py_compile server/community_server.py` (si toca el backend)

## Checklist

- [ ] Sin secretos ni rutas locales hardcodeadas
- [ ] Reglas nuevas: test en `test_rules.gd`
- [ ] Si cambia el contrato de comunidad: actualizado `docs/API.md`
- [ ] Si cambia una decisión: ADR nuevo o actualizado
- [ ] CHANGELOG actualizado si es visible para el jugador
