class_name ChainRule
extends SokobanRule
## Puedes empujar filas enteras de cajas contiguas: la fila entera se
## desplaza si hay hueco tras la última. La lógica vive en GameState.


func _init(p_params: Dictionary = {}) -> void:
	super("chain", p_params)
	title = "Cadena"
	description = "Empujas filas enteras de cajas contiguas a la vez."


static func describe() -> Dictionary:
	return {
		"title": "Cadena",
		"description": "Empuja una fila de cajas contiguas: todas se desplazan juntas.",
	}


static func param_schema() -> Array:
	return []
