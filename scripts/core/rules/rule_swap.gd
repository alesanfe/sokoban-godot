class_name SwapRule
extends SokobanRule
## Cada N turnos se intercambian las posiciones de cajas y objetivos.
## Va por turnos (no por reloj) para que replays y solver sean
## deterministas: el move_log basta para reproducir la partida.


func _init(p_params: Dictionary = {}) -> void:
	super("swap", p_params)
	title = "Intercambio"
	description = "Cada %d turnos se intercambian cajas y objetivos." % _every(p_params)


static func _every(p: Dictionary) -> int:
	return int(p.get("every", int(p.get("interval", 10))))


func after_turn(state) -> void:
	var every := _every(params)
	if every <= 0 or (state.turn + 1) % every != 0:
		return
	_do_swap(state)


func _do_swap(state) -> void:
	# Boxes and goals swap roles: goal cells become boxes, box cells
	# become goals. (A box sitting on a goal effectively stays put.)
	if state.boxes.size() != state.goals.size():
		return
	var new_boxes: Array[Vector2i] = []
	new_boxes.assign(state.goals.keys())
	new_boxes.sort()
	for g in new_boxes:
		if g == state.player or state.twins.has(g) \
				or (state.ghost_active and g == state.ghost_pos):
			return  # don't teleport a box onto someone
	var new_goals: Array[Vector2i] = []
	new_goals.assign(state.boxes)
	new_goals.sort()
	# Goal colors travel with their goals (order-preserved: the color
	# multiset stays the same, mapped in scan order onto new goals).
	var old_goals: Array = state.goals.keys()
	old_goals.sort()
	var old_colors: Array = []
	for g in old_goals:
		old_colors.append(int(state.goal_colors.get(g, 0)))
	# Rebuild EVERY parallel array — the swapped-in boxes are fresh
	# objects, so flag arrays must be realigned, not just mimic.
	state.boxes = new_boxes
	state.box_mimic.clear()
	state.box_mimic.resize(new_boxes.size())
	state.box_colors.clear()
	state.box_colors.resize(new_boxes.size())
	state.box_roll.clear()
	state.box_roll.resize(new_boxes.size())
	state.box_heavy.clear()
	state.box_heavy.resize(new_boxes.size())
	state.box_rest.clear()
	state.box_rest.resize(new_boxes.size())
	state.goals.clear()
	state.goal_colors.clear()
	for i in new_goals.size():
		state.goals[new_goals[i]] = true
		if i < old_colors.size() and old_colors[i] != 0:
			state.goal_colors[new_goals[i]] = old_colors[i]
	# Push budgets reset: the new boxes are "new" objects.
	if state.rule_state.has("push_limit"):
		state.rule_state["push_limit"]["counts"] = PackedInt32Array()


func turns_left(state) -> int:
	var every := _every(params)
	return every - ((state.turn + 1) % every) if every > 0 else 0


func state_key(state) -> String:
	var every := _every(params)
	return "sw:%d" % ((state.turn + 1) % every if every > 0 else 0)


func hud_lines(state) -> PackedStringArray:
	# once counts diverge (a box was destroyed…) the swap no-ops forever:
	# say so instead of counting down to nothing
	if state.boxes.size() != state.goals.size():
		return PackedStringArray(["Intercambio inactivo: cajas ≠ objetivos"])
	return PackedStringArray(["Intercambio en %d turno(s)" % turns_left(state)])


static func describe() -> Dictionary:
	return {
		"title": "Intercambio",
		"description": "Cada N turnos se intercambian las posiciones de las cajas y los objetivos.",
	}


static func param_schema() -> Array:
	return [
		{"key": "every", "label": "Cada N turnos", "type": "int", "min": 2, "max": 60, "default": 10},
	]
