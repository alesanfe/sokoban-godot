class_name TwoPlayersRule
extends SokobanRule
## Dos jugadores controlan al mismo personaje por turnos.
## Con "invert" activado, el jugador 2 tiene los controles invertidos.


func _init(p_params: Dictionary = {}) -> void:
	super("two_players", p_params)
	title = "Dos jugadores"
	description = "Dos jugadores controlan al mismo personaje alternando turnos."


func setup(state) -> void:
	state.rule_state[id] = {"p": 0}


func after_turn(state) -> void:
	var rs: Dictionary = state.rule_state.get(id, {"p": 0})
	rs["p"] = 1 - int(rs.get("p", 0))
	state.rule_state[id] = rs


func active_player(state) -> int:
	return int(state.rule_state.get(id, {}).get("p", 0))


## Direction transform for input: player 2 may have inverted controls.
func transform_input(state, dir: Vector2i) -> Vector2i:
	if active_player(state) == 1 and bool(params.get("invert", false)):
		return -dir
	return dir


func state_key(state) -> String:
	return "tp:%d" % active_player(state)


func hud_lines(state) -> PackedStringArray:
	var extra := " (controles invertidos)" if active_player(state) == 1 and bool(params.get("invert", false)) else ""
	return PackedStringArray(["Turno del Jugador %d%s" % [active_player(state) + 1, extra]])


static func describe() -> Dictionary:
	return {
		"title": "Dos jugadores",
		"description": "El control alterna entre dos jugadores en cada turno.",
	}


static func param_schema() -> Array:
	return [
		{"key": "invert", "label": "Invertir controles del J2", "type": "bool", "default": false},
	]
