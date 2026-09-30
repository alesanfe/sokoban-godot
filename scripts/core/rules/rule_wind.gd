class_name WindRule
extends SokobanRule
## Cada N turnos sopla una ráfaga que desplaza todas las cajas una
## casilla en una dirección (si hay hueco).

const WDIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _init(p_params: Dictionary = {}) -> void:
	super("wind", p_params)
	title = "Viento"
	var names := ["→", "←", "↓", "↑"]
	var i: int = clampi(int(p_params.get("dir", 0)), 0, 3)
	description = "Cada %d turnos, el viento mueve todas las cajas %s." % [
		int(p_params.get("every", 3)), names[i],
	]


func _dir() -> Vector2i:
	return WDIRS[clampi(int(params.get("dir", 0)), 0, 3)]


func after_turn(state) -> void:
	var every: int = int(params.get("every", 3))
	if every <= 0 or (state.turn + 1) % every != 0:
		return
	var d: Vector2i = _dir()
	var order: Array = range(state.boxes.size())
	# downwind boxes move first so the gust can flow through a line
	order.sort_custom(func(a, b): return state.boxes[a].x * d.x + state.boxes[a].y * d.y \
		> state.boxes[b].x * d.x + state.boxes[b].y * d.y)
	for bi in order:
		var nxt: Vector2i = state.box_step_dest(state.boxes[bi], d)
		if nxt != Vector2i(-1, -1):
			state.boxes[bi] = nxt


func state_key(state) -> String:
	var every: int = int(params.get("every", 3))
	return "wind:%d" % ((state.turn + 1) % every if every > 0 else 0)


func hud_lines(state) -> PackedStringArray:
	var every: int = int(params.get("every", 3))
	var remaining: int = every - ((state.turn + 1) % every) if every > 0 else 0
	return PackedStringArray(["Viento: ráfaga en %d turno(s)" % remaining])


static func describe() -> Dictionary:
	return {
		"title": "Viento",
		"description": "Cada N turnos una ráfaga desplaza todas las cajas una casilla.",
	}


static func param_schema() -> Array:
	return [
		{"key": "every", "label": "Cada N turnos", "type": "int", "min": 1, "max": 20, "default": 3},
		{"key": "dir", "label": "Dirección", "type": "select",
			"options": ["→ derecha", "← izquierda", "↓ abajo", "↑ arriba"],
			"default": 0},
	]
