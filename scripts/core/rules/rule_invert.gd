class_name InvertRule
extends SokobanRule
## Controles invertidos: cada dirección mueve al contrario.
## Afecta al input del jugador; el solver y los replays usan
## try_move directo, así que la solución real no cambia.


func _init(p_params: Dictionary = {}) -> void:
	super("invert", p_params)
	title = "Controles invertidos"
	description = "Arriba es abajo y la izquierda es derecha. Suerte."


func transform_input(_state, d: Vector2i) -> Vector2i:
	return -d


static func describe() -> Dictionary:
	return {
		"title": "Controles invertidos",
		"description": "Cada dirección mueve al contrario.",
	}
