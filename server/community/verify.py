"""Verificación de soluciones (Sokoban vanilla).

El cliente exige superar el nivel antes de publicar; el servidor
REJUEGA esa solución cuando el tablero es simulable sin reglas
mutantes. 'moves' viaja en el publish (chars l/r/u/d).

Mutantes → 0 (no verificable: el engine vive en el cliente; ADR-006).
Vanilla + solución válida → 1. Vanilla + solución que no cierra → -1.
"""

from . import config

_VANILLA_SOLID = {"#"}                    # paredes
_GOAL_CHARS = {".", "*", "+", "%"}        # metas (con o sin ocupante)
_BOX_CHARS = {"$", "*", "%"}              # cajas (suelas o en meta)
_PLAYER_CHARS = {"@", "+"}
_KNOWN = (_VANILLA_SOLID | _GOAL_CHARS | _BOX_CHARS | _PLAYER_CHARS
          | {" ", "-", "_"})
_DXDY = {"l": (-1, 0), "r": (1, 0), "u": (0, -1), "d": (0, 1)}


def verify_solution(data: dict, rules: list, moves: str) -> int:
    """0 no-verificable · 1 verificado · -1 simulable y no resuelve."""
    if rules:
        return 0                     # las reglas viven en el cliente
    if not isinstance(moves, str) or not config.MOVE_RE.match(moves) \
            or len(moves) > config.MAX_MOVES:
        return -1
    board = data.get("board", "")
    over = data.get("over", {}) or {}

    walls, boxes, goals, player = set(), set(), set(), None
    verifiable = True
    for y, line in enumerate(board.split("\n")):
        for x, ch in enumerate(line):
            occ = str(over.get(f"{x},{y}", ""))
            c = occ if occ else ch
            if c in _VANILLA_SOLID:
                walls.add((x, y))
            if ch in _GOAL_CHARS or c in _GOAL_CHARS:
                goals.add((x, y))
            if c in _BOX_CHARS:
                boxes.add((x, y))
            if c in _PLAYER_CHARS:
                player = (x, y)
            # tile mutante que el simulador no entiende
            if c not in _KNOWN:
                verifiable = False
    if not verifiable:
        return 0
    if player is None or not goals:
        return -1

    px, py = player
    for m in moves:
        dx, dy = _DXDY[m]
        nx, ny = px + dx, py + dy
        if (nx, ny) in walls:
            continue                 # paso bloqueado: cuenta pero no mueve
        if (nx, ny) in boxes:
            bx, by = nx + dx, ny + dy
            if (bx, by) in walls or (bx, by) in boxes:
                continue             # empuje bloqueado
            boxes.discard((nx, ny))
            boxes.add((bx, by))
        px, py = nx, ny
    return 1 if goals <= boxes else -1
