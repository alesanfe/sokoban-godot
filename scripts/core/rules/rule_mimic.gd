class_name MimicRule
extends SokobanRule
## Las cajas miméticas (&) imitan los movimientos del jugador.


func _init(p_params: Dictionary = {}) -> void:
	super("mimic", p_params)
	title = "Mímica"
	description = "Las cajas miméticas imitan tus movimientos."


func after_player_move(state, dir: Vector2i, _pushed: bool) -> void:
	var md := dir
	if params.get("opposite", false):
		md = -dir
	for i in state.boxes.size():
		if not state.box_mimic[i]:
			continue
		# box_step_dest covers walls/boxes/player/twins/ghost plus
		# portals, torus wrapping and filter glide — same as any push.
		var dest: Vector2i = state.box_step_dest(state.boxes[i], md)
		if dest != Vector2i(-1, -1):
			state.boxes[i] = dest


func state_key(_state) -> String:
	# mimic flags already included via boxes key
	return ""


static func describe() -> Dictionary:
	return {
		"title": "Mímica",
		"description": "Las cajas miméticas (&) copian cada movimiento que haces.",
	}


static func param_schema() -> Array:
	return [{"key": "opposite", "label": "Anti-mímica (van al revés)",
		"type": "bool", "default": false}]
