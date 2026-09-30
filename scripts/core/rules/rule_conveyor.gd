class_name ConveyorRule
extends SokobanRule
## Las cintas > < ^ v arrastran una casilla por turno a las cajas
## (y al jugador) que tengan encima.


func _init(p_params: Dictionary = {}) -> void:
	super("conveyor", p_params)
	title = "Cintas"
	description = "Las cintas > < ^ v arrastran lo que tengan encima."


func after_turn(state) -> void:
	var cells: Array = state.conveyors.keys()
	# downstream cells first: a box rides a belt just one step per turn
	cells.sort_custom(func(a, b): return state.conveyors[a].x * a.x + state.conveyors[a].y * a.y \
		> state.conveyors[b].x * b.x + state.conveyors[b].y * b.y)
	var player_moved := false
	for c in cells:
		var d: Vector2i = state.conveyors[c]
		var bi: int = state.box_at(c)
		if bi != -1:
			var nxt: Vector2i = state.box_step_dest(c, d)
			if nxt != Vector2i(-1, -1):
				state.boxes[bi] = nxt
		elif not player_moved and state.player == c:
			# one belt step per turn — don't keep riding downstream cells
			var nxt: Vector2i = c + d
			if state.is_solid(nxt) or state.has_box(nxt) or state.filters.has(nxt) \
					or state.twins.has(nxt) \
					or (state.ghost_active and state.ghost_pos == nxt):
				continue
			if state._rule_on("portal") and state.portals.has(nxt):
				var ex: Vector2i = state.portals[nxt]
				if not state.is_solid(ex) and not state.has_box(ex) \
						and not state.twins.has(ex) \
						and not (state.ghost_active and state.ghost_pos == ex):
					nxt = ex
				else:
					continue
			state.player = nxt
			state._pickup_key()  # the belt may drop the player on a key
			player_moved = true


static func describe() -> Dictionary:
	return {
		"title": "Cintas",
		"description": "Cintas transportadoras (> < ^ v) que arrastran cajas y jugador.",
	}


static func param_schema() -> Array:
	return []
