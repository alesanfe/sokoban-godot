# ADR-005: Formato de código de nivel SKM1/SKM2

## Contexto

Compartir niveles sin cuenta ni servidor exige un formato textual:
copiar/pegar, sin ficheros, tolerante a clientes de chat.

## Decisión

`SKM1.<len>.<base64url(deflate(json))>` por nivel; `SKM2` para packs.
El JSON incluye tablero extendido (overlays de ocupante), reglas con
parámetros, dificultad y par. `to_code`/`from_code` en
`level_data.gd`; el importador acepta también XSB plano y RLE.

## Alternativas

- XSB solo: no expresa overlays ni reglas mutantes.
- URL con query: exige servidor; los códigos funcionan offline.

## Consecuencias

+ Nivel completo viaja en texto — copiar/pegar basta.
+ `len` permite validar truncamientos antes de descomprimir.
- Códigos grandes para tableros enormes: deflate lo mitiga; el
  límite práctico está en el feed (64 KB), no en el formato.
