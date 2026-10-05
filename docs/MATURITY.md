# Madurez por feature — Sokoban Mutante

Escala: ✅ completo · 🟡 funcional con límites · 🔴 prototipo.

| Feature | Estado | Notas |
|---|---|---|
| Motor sokoban + reglas mutantes | ✅ | Core RefCounted puro (ADR-001) |
| Solver + verificación de niveles | ✅ | Workers; `verify_classics`/`verify_hard` |
| Generador de niveles | ✅ | Con playtest gate (ADR-003) |
| Editor de niveles | ✅ | Con solver integrado y glifos |
| Campaña + niveles clásicos/difíciles | ✅ | Verificados por solver |
| Comunidad (subir/descargar/puntuar) | ✅ | Backend sqlite propio (ADR-004) |
| Leaderboard + replays | ✅ | |
| Temas (dark/light/contrast/CB) | ✅ | Tokens `UiTheme`, paletas por tema |
| i18n ES/EN | ✅ | |
| Servidor de comunidad | 🟡 | http.server+threads — escala limitada por diseño |
| Export web/windows/linux | ✅ | Presets en `export_presets.cfg` |
| Capturas automatizadas | ✅ | `tools/screenshots.gd` con subset |
