# Arquitectura

## Panorama

```
┌────────── UI (scripts/ui/*) ─────────────────────────┐
│ MainScreen (navegación) · GameScreen · EditorScreen  │
│ CommunityScreen · WinPanel · EditorRulesPanel · …    │
└──────────────┬───────────────────────────────────────┘
               │ solo llamadas a core; core NO conoce nodos
┌──────────────┴───────── Core puro (scripts/core/) ───┐
│ GameState (movimiento+reglas)  LevelData (modelo,    │
│ códigos SKM1/XSB)  Solver (BFS, WorkerThreadPool)    │
│ Generator (WorkerThreadPool)  RuleRegistry + rules/  │
│ WinStats · Storage (persistencia user://)            │
│ CommunityService (feed local)  CommunityRemote (HTTP)│
└──────────────┬───────────────────────────────────────┘
               │ JSON REST (opcional)
        ┌──────┴───────┐
        │ community_server.py  (Python stdlib + SQLite WAL)
        └──────────────┘
```

## Reglas de dependencia

- `core/*` no puede depender de `ui/*` ni de `Node`s (testeable
  headless con `extends SceneTree`).
- `ui/*` consume core y pinta; la pantalla orquesta, los componentes
  (`WinPanel`, `EditorRulesPanel`) encapsulan su propio layout.
- Async (solver/generador): trabajo en worker threads, callback al
  hilo principal; cada pantalla genera sus propios datos.

## Datos

- **Nivel**: `LevelData` — board ASCII, overlays (`{x,y}`→char),
  reglas `[{id,params}]`, metadatos. `to_code()` → `SKM1.<zlib+base64>`.
- **Persistencia local**: `user://` vía `Storage` (atomic write con
  `.tmp`+rename, recuperación de `.bak`). Progreso, récords, replays,
  niveles propios, settings, feed local de comunidad.
- **Comunidad remota**: espejo `remote_entries` dentro del catálogo
  local; `CommunityService` unifica local+remoto (`id` vs `r:<rid>`),
  deduplicando la publicación propia por `remote_id`.

## Flujo representativo — publicar un nivel

Editor → `build_level()` → `LevelData.validate()` → gate "supera tu
nivel" (`Storage.is_playtested`) → `CommunityService.publish` → ficha
local `own=true` → si hay backend y sesión: `CommunityRemote.publish`
(Bearer) → servidor valida shape → `remote_id`+`token` persistidos en
la ficha → siguiente `sync_remote` deduplica por `remote_id`.

## Decisiones

Ver `docs/decisions/` — ADR-001 core estático, ADR-002 solver en
workers, ADR-003 playtest-gate, ADR-004 backend SQLite stdlib.
