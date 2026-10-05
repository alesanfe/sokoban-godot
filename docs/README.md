# Documentación — Sokoban Mutante

## Juego y dominio

- [Reglas](RULES.md) — las 30 reglas mutantes del juego
- [UX](UX.md) — convenciones de interfaz y accesibilidad
- [Arquitectura](ARCHITECTURE.md) — core puro + UI Godot + comunidad
- [Modelo de datos](DATA_MODEL.md) — niveles, progreso, comunidad
- [API](API.md) — contrato del servidor de comunidad

## Requisitos y gobernanza

- [Requisitos](REQUIREMENTS.md) — funcionales y no funcionales
- [Gobernanza](GOVERNANCE.md) — roles y proceso de decisión
- [Madurez](MATURITY.md) — autoevaluación por dimensión
- [Calidad](QUALITY.md) — atributos prioritarios y presupuestos
- [Dependencias](DEPENDENCIES.md) — política e inventario
- [Deprecaciones](DEPRECATION.md) — ciclo de vida de formatos y API
- [Deuda técnica](TECH_DEBT.md) — registro formal

## Seguridad y privacidad

- [Modelo de amenazas](THREAT_MODEL.md) — feed comunitario, códigos de nivel
- [Privacidad](PRIVACY.md) — datos que trata el juego

## Decisiones (ADRs)

- [Índice de ADRs](decisions/README.md) — core sin nodos, solver en
  workers, playtest-gate, SQLite, share-codes, trust/sync model

## Operaciones

- [Operaciones](OPERATIONS.md) — servidor de comunidad
- [Checklist de release](operations/release-checklist.md)
- [Incidentes](operations/incidents.md)
- [SLO](operations/slo.md)
