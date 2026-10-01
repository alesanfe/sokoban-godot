class_name QuakeRule
extends SokobanRule
## Terremoto: cada N turnos un temblor desliza TODAS las cajas una
## casilla — la dirección rota cada seísmo (→ ↓ ← ↑), así que ninguna
## posición es estable para siempre.


func _init(p_params: Dictionary = {}) -> void:
	super("quake", p_params)
	title = "Terremoto"
	description = ("Cada %d turnos tiembla: todas las cajas resbalan"
		+ " un paso (la dirección rota)." % int(p_params.get("every", 5)))


func after_turn(state) -> void:
	var every: int = int(params.get("every", 5))
	if every <= 0 or (state.turn + 1) % every != 0:
		return
	var q: int = (state.turn + 1) / every  # cuántos seísmos han ocurrido
	var d: Vector2i = [Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(0, -1)][(q - 1) % 4]
	# move downwind boxes first so the quake can flow through a line
	var order: Array = range(state.boxes.size())
	order.sort_custom(func(a, b): return state.boxes[a].x * d.x + state.boxes[a].y * d.y \
		> state.boxes[b].x * d.x + state.boxes[b].y * d.y)
	for bi in order:
		var nxt: Vector2i = state.box_step_dest(state.boxes[bi], d)
		if nxt != Vector2i(-1, -1):
			state.boxes[bi] = nxt


func state_key(_state) -> String:
	return ""  # deterministic from turn; canonical already counts it


func hud_lines(state) -> PackedStringArray:
	var every: int = int(params.get("every", 5))
	var remaining: int = every - ((state.turn + 1) % every) if every > 0 else 0
	var q: int = (state.turn + 1) / every + 1
	var arrow: String = ["→", "↓", "←", "↑"][(q - 1) % 4]
	return PackedStringArray(["Terremoto: próximo %s en %d turno(s)" % [arrow, remaining]])


static func describe() -> Dictionary:
	return {
		"title": "Terremoto",
		"description": "Cada N turnos un seísmo desliza todas las cajas un paso; la dirección rota.",
	}


static func param_schema() -> Array:
	return [
		{"key": "every", "label": "Cada N turnos", "type": "int", "min": 2, "max": 30, "default": 5},
	]
