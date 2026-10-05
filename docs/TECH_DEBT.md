# Deuda técnica — Sokoban Mutante

## Conocida

| Item | Impacto | Dirección |
|---|---|---|
| `scripts/ui/` mezcla pantallas grandes con helpers | Navegación del código | Extraer `ui/widgets` si crece |
| Solver en worker threads sin cancelación dura | Espera en niveles grandes | Timeout + kill del thread |
| Servidor comunidad = http.server + threads | Carga limitada por diseño | Migrar a ASGI si supera ~50 rps |
| Niveles de comunidad sin moderación remota | Contenido offline-first | Revisión por `SKM_ADMINS` |
| `tools/_shots/` mezcla salida de trabajo | Ruido en git si se commitea | Ya gitignored — mantener así |

## Padrón (añadir al resolver o al aceptar)

- Los tests `verify_*` descubren niveles irresolubles — un nivel
  roto del catálogo se registra aquí hasta arreglar el .dat.
- Convenciones: ADR-003 (playtest gate) exige que todo nivel nuevo
  pase el solver antes de commitear.
