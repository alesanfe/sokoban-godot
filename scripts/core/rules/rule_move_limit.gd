class_name MoveLimitRule
extends SokobanRule
## Cuenta atrás de turnos: si se agotan sin resolver, pierdes.
## Análogo a las "clear conditions" de Mario Maker.


func _init(p_params: Dictionary = {}) -> void:
	super("move_limit", p_params)
	title = "Cuenta atrás"
	var m: int = int(p_params.get("max", 30))
	description = "Debes resolver el nivel en %d turnos o menos." % m


func on_turn_end(state) -> void:
	# on_turn_end runs after every resolver, the solved latch AND the
	# turn increment — a conveyor/quake that resolves the board on the
	# last turn counts as a win regardless of rule order.
	var m: int = int(params.get("max", 30))
	if not state.solved and state.turn >= m:
		state.lost = true
		state.lost_reason = "Se agotaron los %d movimientos." % m


func hud_lines(state) -> PackedStringArray:
	var m: int = int(params.get("max", 30))
	return PackedStringArray(["Cuenta atrás: quedan %d turnos" % maxi(0, m - state.turn)])


func state_key(state) -> String:
	var m: int = int(params.get("max", 30))
	return "ml:%d" % maxi(0, m - state.turn)


static func describe() -> Dictionary:
	return {
		"title": "Cuenta atrás",
		"description": "Resuelve el nivel antes de agotar los movimientos.",
	}


static func param_schema() -> Array:
	return [{"key": "max", "label": "Máx. turnos", "type": "int",
		"min": 1, "max": 500, "default": 30}]
