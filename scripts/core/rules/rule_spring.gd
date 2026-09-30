class_name SpringRule
extends SokobanRule
## Muelle: cada empujón te rebota una casilla hacia atrás (si hay
## hueco). Empujar en un pasillo de una celda te saca disparado.


func _init(p_params: Dictionary = {}) -> void:
	super("spring", p_params)
	title = "Muelle"
	description = "Empujar una caja te rebota hacia atrás."


func after_player_move(state, dir: Vector2i, pushed: bool) -> void:
	if not pushed:
		return
	var back: Vector2i = state.player - dir
	if not state.in_bounds(back) or state.walls.has(back) \
			or state.peekaboo_walls.has(back) or state.weak_walls.has(back) \
			or state.door_cells.has(back) or state.filters.has(back) \
			or state.box_at(back) != -1 or state.twins.has(back) \
			or (state.ghost_active and state.ghost_pos == back):
		return  # el rebote no cabe — quieto
	state.player = back
	state._pickup_key()  # the bounce may land on a key
	state.fx_teleport.emit(back)


static func describe() -> Dictionary:
	return {
		"title": "Muelle",
		"description": "Cada empujón te rebota una casilla hacia atrás si hay hueco.",
	}
