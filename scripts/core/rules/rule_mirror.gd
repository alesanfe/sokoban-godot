class_name MirrorRule
extends SokobanRule
## Espejo: cada empujón también empuja a la caja que ocupa la posición
## reflejada (eje vertical central del tablero) de donde empezó la tuya.
## Param "h": espejo horizontal en vez de vertical.


func _init(p_params: Dictionary = {}) -> void:
	super("mirror", p_params)
	title = "Espejo"
	description = "Los empujones se reflejan en el eje %s del tablero." % (
		"horizontal" if bool(p_params.get("h", false)) else "vertical")


func after_push(state, box_idx: int, dir: Vector2i) -> void:
	if box_idx < 0 or box_idx >= state.boxes.size():
		return
	var h := bool(params.get("h", false))
	# the pushed box's OLD position, mirrored — recorded by the engine
	# so ice slides / portals / rolling boxes don't corrupt it
	var old: Vector2i = state.box_pushed_from if state.box_pushed_from \
			!= Vector2i(-1, -1) else state.boxes[box_idx] - dir
	var mp := Vector2i(old.x, state.height - 1 - old.y) if h \
		else Vector2i(state.width - 1 - old.x, old.y)
	var bi: int = state.box_at(mp)
	if bi == -1 or bi == box_idx:
		return
	var nxt: Vector2i = state.box_step_dest(state.boxes[bi], dir)
	if nxt != Vector2i(-1, -1):
		state.boxes[bi] = nxt
		state.fx_teleport.emit(nxt)


static func describe() -> Dictionary:
	return {
		"title": "Espejo",
		"description": "Cada empujón también empuja la caja reflejada en el eje del tablero.",
	}


static func param_schema() -> Array:
	return [
		{"key": "h", "label": "Espejo horizontal", "type": "bool", "default": false},
	]
