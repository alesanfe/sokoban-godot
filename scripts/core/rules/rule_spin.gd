class_name SpinRule
extends SokobanRule
## Cada turno los controles giran 90° en sentido horario: lo que antes
## era "derecha" pasa a ser "abajo", luego "izquierda"…

const ORDER := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]  # r,d,l,u


func _init(p_params: Dictionary = {}) -> void:
	super("spin", p_params)
	title = "Vértigo"
	description = "Tus controles giran 90° después de cada movimiento."


func transform_input(state, dir: Vector2i) -> Vector2i:
	var i: int = ORDER.find(dir)
	if i == -1:
		return dir
	return ORDER[(i + state.turn) % 4]


func hud_lines(state) -> PackedStringArray:
	return PackedStringArray(["Controles girados %d°" % ((state.turn % 4) * 90)])


static func describe() -> Dictionary:
	return {
		"title": "Vértigo",
		"description": "Los controles giran 90° en cada turno.",
	}


static func param_schema() -> Array:
	return []
