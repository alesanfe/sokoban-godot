class_name LinkRule
extends SokobanRule
## Enlace cuántico: empujar una caja de color mueve TODAS las cajas de
## ese color en la misma dirección (la que pueda). Con "all" también
## las cajas normales se enlazan entre sí.


func _init(p_params: Dictionary = {}) -> void:
	super("link", p_params)
	title = "Enlace cuántico"
	description = "Empujar una caja de color mueve a todas las de su color."


var _old: Array = []  # box positions at turn start (before_move)


func before_move(state, _dir: Vector2i) -> void:
	_old = state.boxes.duplicate()


func after_push(state, box_idx: int, dir: Vector2i) -> void:
	if box_idx < 0 or box_idx >= state.boxes.size():
		return
	var col: int = state.box_colors[box_idx] if box_idx < state.box_colors.size() else 0
	if col == 0 and not bool(params.get("all", false)):
		return
	# move linked boxes front-to-back so a line of them doesn't pile up
	var order: Array[int] = []
	for i in state.boxes.size():
		if i == box_idx:
			continue
		var c2: int = state.box_colors[i] if i < state.box_colors.size() else 0
		if c2 == col:
			order.append(i)
	order.sort_custom(func(a, b): return state.boxes[a].x * dir.x + state.boxes[a].y * dir.y \
		> state.boxes[b].x * dir.x + state.boxes[b].y * dir.y)
	for i in order:
		# boxes already displaced this turn (chain members, bond
		# clusters, mirror pushes) must not move a second time
		if i < _old.size() and state.boxes[i] != _old[i]:
			continue
		var nxt: Vector2i = state.box_step_dest(state.boxes[i], dir)
		if nxt != Vector2i(-1, -1):
			state.boxes[i] = nxt


static func describe() -> Dictionary:
	return {
		"title": "Enlace cuántico",
		"description": "Empujar una caja de color mueve todas las demás de ese color un paso igual.",
	}


static func param_schema() -> Array:
	return [
		{"key": "all", "label": "También cajas normales", "type": "bool", "default": false},
	]
