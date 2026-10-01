# ADR-002: Solver y generador en worker threads con escalado

## Contexto

Un BFS de Sokoban puede explorar decenas de miles de estados; en el
hilo principal congela la UI (verificación del editor, par al ganar).

## Decisión

`WorkerThreadPool` + callbacks diferidos al hilo principal. Presupuesto
`MAX_STATES = 60000`; al agotarse el presupuesto (no "sin solución")
se reintenta ×4 y ×10 con el estado serializado de nuevo (el solve
muta, no se reutiliza).

## Consecuencias

+ UI fluida durante solve/generación.
+ La pantalla que lanza el trabajo puede morir antes del callback →
  cada call site debe comprobar `is_instance_valid`/identidad.
+ El test de determinismo fuzz cubre la serialización entre retries.
