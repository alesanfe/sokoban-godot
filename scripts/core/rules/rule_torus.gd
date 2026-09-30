class_name TorusRule
extends SokobanRule
## Los bordes del tablero están conectados: salir por un lado hace
## que aparezcas por el opuesto. La lógica vive en GameState.


func _init(p_params: Dictionary = {}) -> void:
	super("torus", p_params)
	title = "Mundo toro"
	description = "Los bordes se conectan: sal por un lado, entra por el otro."


static func describe() -> Dictionary:
	return {
		"title": "Mundo toro",
		"description": "Los bordes del tablero conectan con el lado opuesto.",
	}


static func param_schema() -> Array:
	return []
