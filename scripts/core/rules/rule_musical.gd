class_name MusicalRule
extends SokobanRule
## Sillas: cada N turnos las cajas rotan posiciones en anillo — la caja
## i pasa a ocupar el hueco de la siguiente (en orden de lectura).
## Las metas no se mueven: es un patio de butacas.


func _init(p_params: Dictionary = {}) -> void:
	super("musical", p_params)
	title = "Sillas"
	description = "Cada %d turnos las cajas rotan posiciones entre sí." % int(p_params.get("every", 4))


func after_turn(state) -> void:
	var every: int = int(params.get("every", 4))
	if every <= 0 or (state.turn + 1) % every != 0:
		return
	var n: int = state.boxes.size()
	if n < 2:
		return
	var last: Vector2i = state.boxes[n - 1]
	for i in range(n - 1, 0, -1):
		state.boxes[i] = state.boxes[i - 1]
	state.boxes[0] = last


func hud_lines(state) -> PackedStringArray:
	var every: int = int(params.get("every", 4))
	var remaining: int = every - ((state.turn + 1) % every) if every > 0 else 0
	return PackedStringArray(["Sillas: rotación en %d turno(s)" % remaining])


static func describe() -> Dictionary:
	return {
		"title": "Sillas",
		"description": "Cada N turnos todas las cajas rotan una posición en anillo.",
	}


static func param_schema() -> Array:
	return [
		{"key": "every", "label": "Cada N turnos", "type": "int", "min": 1, "max": 30, "default": 4},
	]
