# UX — sistema de diseño, flujos y validación

Estándar UX/UI del proyecto: qué componentes existen, qué estados
soportan, cómo se validan y qué queda fuera por requerir usuarios
reales.

## Sistema de diseño

### Tokens (`scripts/ui/ui_theme.gd`)

- **Temas**: `dark`, `light`, `high_contrast`, `colorblind`
  (`UiTheme.ORDER`), persistidos en `settings.ui_theme`.
- **Estados por botón**: normal / hover / pressed / disabled /
  focus (anillo visible, generado como StyleBox).
- **Escala**: `content_scale_factor` 0.85–1.30 (opción
  «Tamaño de la interfaz»).
- **Color semántico**: éxito `✓`, aviso `⚠`, error `✗` — nunca
  solo color; siempre con prefijo de símbolo en el texto.

### Componentes (`scripts/ui/widgets.gd`)

| Helper | Uso | Cuándo NO usarlo |
|---|---|---|
| `label(text, size, color)` | Texto y títulos | Para feedback → `status()` |
| `button(text)` | Acción secundaria | Para la acción principal → `primary()` |
| `primary(button)` | Una acción por pantalla | Acciones destructivas |
| `status(lbl, text)` | Canal de estado (visual + TTS) | Feedback no crítico → `toast()` |
| `toast(root, text)` | Confirmación breve no crítica | Errores que exigen reacción → `status()` |
| `stars(n)` | Dificultad/medallas | — |
| `focus_first(node)` | Foco inicial tras montar la pantalla | — |
| `hsep()` | Separador semántico de secciones | Espaciado fino → `separation` |

### Reglas de contenido (voz y tono)

- Botones con verbo específico («Guardar en Mis niveles», no «Aceptar»).
- Feedback con prefijo de estado: `✓` éxito, `⚠` aviso/recuperable,
  `✗` error. El símbolo va en el texto — la lectura por TTS lo recibe.
- Instrucción antes de la entrada («pega un código y pulsa
  Comprobar») en lugar de controles deshabilitados sin explicación.
- Estados vacíos explican qué falta y qué hacer («Sin niveles que
  coincidan con «X»»).

## Flujos verificables

| Flujo | Actor | Entrada | Camino ideal | Errores previstos | Métrica |
|---|---|---|---|---|---|
| Jugar nivel | Jugador | Menú → Campaña | Jugar → completar | Deadlock, restart | wins/restarts, tiempo vs par |
| Continuar | Jugador | Menú → Continuar | Reanuda partida | Save incompatible | — |
| Importar | Jugador | Menú → Importar | Pegar → Comprobar → Jugar | Código inválido (status inline) | — |
| Crear y publicar | Creador | Menú → Editor | Pintar → Verificar → Probar (ganar) → Publicar | Irresoluble, cambios sin guardar | community funnel |
| Generar desafío | Jugador | Menú → Desafío | Ajustar → Generar → Jugar | Generación fallida → reintento | — |
| Reasignar controles | Usuario teclado | Menú → Controles | Elegir acción → pulsar tecla | Colisión → aviso en línea | — |
| Ajustar accesibilidad | Usuario AT | Menú → Opciones | Tema/escala/lector/movimiento | — | — |

## Validación implementada

- `tests/test_ui.gd`: smoke por pantalla + cada screen debe tener
  al menos un control enfocable por teclado (trampa de foco = fallo).
- `tools/screenshots.gd`: capturas reales por pantalla/overlay +
  barrido de resoluciones 800×600 / 1024×600 / 1600×900.
- `gdlint` + suite completa en CI.

## Limitaciones honestas

Lo que NO se puede validar solo con código y queda pendiente de
proceso, no de implementación:

- Investigación con usuarios reales (entrevistas, SUS, tests de
  usabilidad) — los KPIs locales de `docs/REQUIREMENTS.md` son la
  aproximación offline.
- Prueba manual con lectores de pantalla (Narrator/VoiceOver) — el
  código anuncia pantallas, toasts y status vía `DisplayServer.tts_*`,
  pero la calidad de la voz solo se verifica en el SO real.
- Card sorting / tree testing — la arquitectura de información es
  la propuesta por el diseño, no validada con participantes.
