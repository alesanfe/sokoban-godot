class_name LifeRule
extends SokobanRule
## Juego de la Vida: cada N turnos las cajas viven por Conway —
## nace una en cada celda libre con exactamente 3 vecinas, muere la
## que tiene <2 o >3. Determinista, absurdo y muy, muy mutante.


func _init(p_params: Dictionary = {}) -> void:
	super("life", p_params)
	title = "Juego de la Vida"
	description = "Cada %d turnos las cajas siguen Conway (nace con 3, muere con <2 o >3)." % int(p_params.get("every", 4))


func after_turn(state) -> void:
	var every: int = int(params.get("every", 4))
	var cap: int = int(params.get("cap", 30))
	if every <= 0 or (state.turn + 1) % every != 0:
		return
	# neighbor counts over the whole board
	var counts := {}
	for p in state.boxes:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var c: Vector2i = p + Vector2i(dx, dy)
				counts[c] = int(counts.get(c, 0)) + 1
	# simultaneous step: deaths first, then births (cells freed by a
	# death don't count as free for births this generation)
	var deaths: Array[int] = []
	for i in state.boxes.size():
		var nb: int = counts.get(state.boxes[i], 0)
		if nb < 2 or nb > 3:
			deaths.append(i)
	for i in range(deaths.size() - 1, -1, -1):
		state._remove_box(deaths[i])
	for c in counts.keys():
		if counts[c] == 3 and state.boxes.size() < cap \
				and state.is_free_for_box(c) and c != state.player \
				and not state.pit_cells.has(c) \
				and not state.filters.has(c):
			state._add_box(c)


func hud_lines(state) -> PackedStringArray:
	var every: int = int(params.get("every", 4))
	var remaining: int = every - ((state.turn + 1) % every) if every > 0 else 0
	return PackedStringArray(["Vida: %d cajas, generación en %d turno(s)" % [
		state.boxes.size(), remaining]])


static func describe() -> Dictionary:
	return {
		"title": "Juego de la Vida",
		"description": "Cada N turnos las cajas viven por Conway: nacen con 3 vecinas, mueren con <2 o >3.",
	}


static func param_schema() -> Array:
	return [
		{"key": "every", "label": "Cada N turnos", "type": "int", "min": 1, "max": 30, "default": 4},
		{"key": "cap", "label": "Máx. cajas", "type": "int", "min": 2, "max": 60, "default": 30},
	]
