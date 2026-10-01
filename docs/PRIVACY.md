# Privacidad

## Juego

- **Sin telemetría**: el juego no envía nada a ningún servicio por
  defecto. Todo el progreso queda en `user://` del dispositivo.
- Comunidad remota es **opt-in**: solo si el jugador configura la URL
  del servidor en Opciones.

## Backend (quien lo autoaloja es el responsable del tratamiento)

| Dato | Por qué | Retención | Eliminación |
|---|---|---|---|
| username | cuenta | hasta que el operador la borre | SQL manual |
| password | login | — (solo hash pbkdf2) | con la cuenta |
| token sesión | auth | ≤30 días, deslizante | logout/expire |
| niveles publicados | feed | hasta remove/podar | remove propio o admin |
| IP (rate table) | anti-abuso | ≤60 s | automática |

- Sin emails, sin tracking, sin cookies, sin terceros.
- `/api/feed` es público: no publicar nada que no deba serlo.

## Minimización

El diseño evita datos innecesarios por defecto: el feed solo expone
título, autor, tablero, reglas, contadores y `verified`. No hay
analítica de uso más allá de los contadores públicos de cada entrada.
