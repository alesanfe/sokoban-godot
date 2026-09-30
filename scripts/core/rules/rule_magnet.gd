class_name MagnetRule
extends SokobanRule
## Las cajas son magnéticas: cada turno se acercan (o se alejan, con
## "repel") una casilla hacia el jugador si el camino está libre.


func _init(p_params: Dictionary = {}) -> void:
	super("magnet", p_params)
	var repel: bool = bool(p_params.get("repel", false))
	title = "Repulsor" if repel else "Imán"
	description = (
		"Las cajas se alejan de ti una casilla por turno." if repel
		else "Las cajas se acercan a ti una casilla por turno."
	)


func after_turn(state) -> void:
	var repel: bool = bool(params.get("repel", false))
	for bi in state.boxes.size():
		var delta: Vector2i = state.player - state.boxes[bi]
		if repel:
			delta = -delta
		var axes: Array[Vector2i] = []
		if absi(delta.x) >= absi(delta.y):
			if delta.x != 0:
				axes.append(Vector2i(signi(delta.x), 0))
			if delta.y != 0:
				axes.append(Vector2i(0, signi(delta.y)))
		else:
			if delta.y != 0:
				axes.append(Vector2i(0, signi(delta.y)))
			if delta.x != 0:
				axes.append(Vector2i(signi(delta.x), 0))
		for a in axes:
			var nxt: Vector2i = state.box_step_dest(state.boxes[bi], a)
			if nxt != Vector2i(-1, -1):
				state.boxes[bi] = nxt
				break


static func describe() -> Dictionary:
	return {
		"title": "Imán",
		"description": "Las cajas se acercan (o alejan) de ti una casilla por turno.",
	}


static func param_schema() -> Array:
	return [
		{"key": "repel", "label": "Repeler en vez de atraer", "type": "bool", "default": false},
	]
