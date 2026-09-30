class_name PullRule
extends SokobanRule
## No puedes empujar cajas: solo puedes arrastrarlas.
## Al alejarte de una caja adyacente, te sigue.


func _init(p_params: Dictionary = {}) -> void:
	super("pull", p_params)
	title = "Arrastre"
	description = "No empujas: al alejarte de una caja adyacente, la arrastras."


func can_push(_state, _box_idx: int, _dir: Vector2i) -> bool:
	return false


func after_player_move(state, dir: Vector2i, _pushed: bool) -> void:
	# Only a plain orthogonal walk drags: portal teleports, torus wraps
	# and twin swaps change `player` without vacating the cell behind.
	var came: Vector2i = state.player_came_from
	if came == Vector2i(-1, -1) or state.player != came + dir:
		return
	# The box that was behind the player follows into the vacated cell.
	var behind: Vector2i = came - dir
	var bi: int = state.box_at(behind)
	if bi == -1:
		return
	# A drag is a displacement: other rules' vetoes apply (a maxed-out
	# push_limit box can't be dragged) and budgets charge for it.
	if state.rules_enabled:
		for rule in state.rules:
			if rule == self:
				continue
			if not rule.can_push(state, bi, dir) \
					or not rule.can_move(state, bi, dir):
				return
	# box_step_dest: same legality as a push (portals, torus, filters).
	var dest: Vector2i = state.box_step_dest(behind, dir)
	if dest == Vector2i(-1, -1):
		return
	state.box_pushed_from = behind
	state.boxes[bi] = dest
	if state.rules_enabled:
		for rule in state.rules:
			if rule != self:
				rule.after_box_moved(state, bi, dir)


static func describe() -> Dictionary:
	return {
		"title": "Arrastre",
		"description": "Las cajas no se empujan: te siguen cuando te alejas de ellas.",
	}


static func param_schema() -> Array:
	return []
