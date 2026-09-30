class_name PortalRule
extends SokobanRule
## Las casillas 'o' y 'O' son portales emparejados: todo lo que entra
## por una sale por su pareja (jugador y cajas). La lógica vive en
## GameState y en los tiles del tablero.


func _init(p_params: Dictionary = {}) -> void:
	super("portal", p_params)
	title = "Portales"
	description = "Las casillas o y O teletransportan por parejas."


func hud_lines(state) -> PackedStringArray:
	if state.portals.is_empty():
		return PackedStringArray()
	return PackedStringArray(["Portales: o↔o  O↔O"])


static func describe() -> Dictionary:
	return {
		"title": "Portales",
		"description": "Portales emparejados (o, O) que teletransportan jugador y cajas.",
	}


static func param_schema() -> Array:
	return []
