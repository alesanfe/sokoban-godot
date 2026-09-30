class_name RotateRule
extends SokobanRule
## El escenario gira 90 grados cada N turnos.


func _init(p_params: Dictionary = {}) -> void:
	super("rotate", p_params)
	title = "Rotación"
	description = "El escenario gira 90° cada %d turnos." % int(p_params.get("every", 5))


func after_turn(state) -> void:
	var every: int = int(params.get("every", 5))
	if every <= 0:
		return
	if (state.turn + 1) % every == 0:
		_rotate(state, int(params.get("cw", 1)))


func _rotate(state, cw: int) -> void:
	var W: int = state.width
	var H: int = state.height
	var map := func(p: Vector2i) -> Vector2i:
		if cw >= 0:
			return Vector2i(H - 1 - p.y, p.x)
		return Vector2i(p.y, W - 1 - p.x)
	var rmap := func(v: Vector2i) -> Vector2i:
		return Vector2i(-v.y, v.x) if cw >= 0 else Vector2i(v.y, -v.x)
	# One transform API re-keys every position dictionary — walls, goals,
	# holes, fragile floors, rails, filters, twins… nothing stays behind.
	state.transform_cells(map, rmap)
	state.width = H
	state.height = W


func hud_lines(state) -> PackedStringArray:
	var every: int = int(params.get("every", 5))
	var remaining: int = every - ((state.turn + 1) % every) if every > 0 else 0
	return PackedStringArray([
		"Rotación: gira en %d turno(s)" % remaining,
	])


func state_key(state) -> String:
	return "rot:%d:%d" % [state.width, state.height]


static func describe() -> Dictionary:
	return {
		"title": "Rotación",
		"description": "El escenario entero gira 90° cada N turnos.",
	}


static func param_schema() -> Array:
	return [
		{"key": "every", "label": "Cada N turnos", "type": "int", "min": 1, "max": 50, "default": 5},
		{"key": "cw", "label": "Sentido", "type": "select",
			"options": ["Horario", "Antihorario"], "values": [1, -1],
			"default": 1},
	]
