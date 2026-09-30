class_name RepelRule
extends SokobanRule
## Polos opuestos (inspirado en Velsokomagnet): al final de cada turno,
## toda caja en tu misma fila o columna a distancia ≥2 resbala un paso
## lejos de ti. Las adyacentes no se mueven (esas las empujas tú).


func _init(p_params: Dictionary = {}) -> void:
	super("repel", p_params)
	title = "Polos opuestos"
	description = "Las cajas en tu fila/columna se alejan un paso cada turno (a distancia ≥2)."


func after_turn(state) -> void:
	var p: Vector2i = state.player
	# deterministic order: nearest boxes move first (they've "felt"
	# the field longest) — sorted by Manhattan distance ascending
	var order: Array = range(state.boxes.size())
	order.sort_custom(func(a, b): return \
		absi(state.boxes[a].x - p.x) + absi(state.boxes[a].y - p.y) \
		< absi(state.boxes[b].x - p.x) + absi(state.boxes[b].y - p.y))
	for bi in order:
		var b: Vector2i = state.boxes[bi]
		var dx := b.x - p.x
		var dy := b.y - p.y
		var d := Vector2i.ZERO
		if dx != 0 and dy == 0 and absi(dx) >= 2:
			d = Vector2i(signi(dx), 0)
		elif dy != 0 and dx == 0 and absi(dy) >= 2:
			d = Vector2i(0, signi(dy))
		if d != Vector2i.ZERO:
			var nxt: Vector2i = state.box_step_dest(b, d)
			if nxt != Vector2i(-1, -1):
				state.boxes[bi] = nxt


static func describe() -> Dictionary:
	return {
		"title": "Polos opuestos",
		"description": "Las cajas en tu fila o columna resbalan un paso lejos de ti cada turno (distancia ≥2).",
	}
