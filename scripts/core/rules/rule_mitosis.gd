class_name MitosisRule
extends SokobanRule
## Mitosis: cada N turnos, cada caja engendra una copia (con sus mismos
## flags) en la primera casilla libre adyacente — hasta un tope.
## Combina terroríficamente bien con sumideros, bombas y quota.

const DIRS := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]


func _init(p_params: Dictionary = {}) -> void:
	super("mitosis", p_params)
	title = "Mitosis"
	description = "Cada %d turnos las cajas se dividen (máx. %d)." % [
		int(p_params.get("every", 6)), int(p_params.get("cap", 10)),
	]


func after_turn(state) -> void:
	var every: int = int(params.get("every", 6))
	var cap: int = int(params.get("cap", 10))
	if every <= 0 or (state.turn + 1) % every != 0:
		return
	var n0: int = state.boxes.size()  # solo dividen las que ya existían
	for i in n0:
		if state.boxes.size() >= cap:
			break
		var p: Vector2i = state.boxes[i]
		for d in DIRS:
			if state.is_free_for_box(p + d) and not state.filters.has(p + d):
				state._add_box(p + d,
					state.box_colors[i] if i < state.box_colors.size() else 0,
					state.box_mimic[i] if i < state.box_mimic.size() else false,
					state.box_roll[i] if i < state.box_roll.size() else false,
					state.box_heavy[i] if i < state.box_heavy.size() else false)
				break


func hud_lines(state) -> PackedStringArray:
	var every: int = int(params.get("every", 6))
	var remaining: int = every - ((state.turn + 1) % every) if every > 0 else 0
	return PackedStringArray(["Mitosis: %d cajas, división en %d turno(s)" % [
		state.boxes.size(), remaining]])


static func describe() -> Dictionary:
	return {
		"title": "Mitosis",
		"description": "Cada N turnos cada caja engendra una copia en una celda libre (con tope).",
	}


static func param_schema() -> Array:
	return [
		{"key": "every", "label": "Cada N turnos", "type": "int", "min": 1, "max": 30, "default": 6},
		{"key": "cap", "label": "Máx. cajas", "type": "int", "min": 1, "max": 40, "default": 10},
	]
