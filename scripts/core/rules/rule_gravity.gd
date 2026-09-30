class_name GravityRule
extends SokobanRule
## Las cajas y el jugador caen hasta apoyarse en algo sólido
## (pared, borde u otra caja). La vista lateral se abre en la mente.


func _init(p_params: Dictionary = {}) -> void:
	super("gravity", p_params)
	title = "Gravedad"
	description = "Las cajas y tú caéis hasta apoyaros en algo sólido."


func after_turn(state) -> void:
	var down := Vector2i(0, 1)
	var moved := true
	var guard := 0
	while moved and guard < 400:
		moved = false
		guard += 1
		var order: Array = range(state.boxes.size())
		order.sort_custom(func(a, b): return state.boxes[a].y > state.boxes[b].y)
		for bi in order:
			var nxt: Vector2i = state.box_step_dest(state.boxes[bi], down)
			if nxt != Vector2i(-1, -1):
				state.boxes[bi] = nxt
				moved = true
		var pb: Vector2i = state.player + down
		if state._rule_on("torus") and (not state.in_bounds(pb) or (state.walls.has(pb) and state._is_edge_cell(pb))):
			pb = state._wrap_dest(state.player, down)
		if not state.is_solid(pb) and not state.has_box(pb) and pb != state.player \
				and not state.filters.has(pb) and not state.twins.has(pb):
			if state._rule_on("portal") and state.portals.has(pb):
				var ex: Vector2i = state.portals[pb]
				if not state.is_solid(ex) and not state.has_box(ex) \
						and not state.filters.has(ex) \
						and not state.twins.has(ex) \
						and not (state.ghost_active and state.ghost_pos == ex):
					pb = ex
				else:
					pb = state.player
			if pb != state.player:
				state.player = pb
				moved = true


static func describe() -> Dictionary:
	return {
		"title": "Gravedad",
		"description": "Todo lo que no se apoya cae: las cajas… y tú.",
	}


static func param_schema() -> Array:
	return []
