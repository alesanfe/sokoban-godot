class_name GhostRule
extends SokobanRule
## Al reiniciar, tu intento anterior se repite como un fantasma que
## también puede empujar cajas.


func _init(p_params: Dictionary = {}) -> void:
	super("ghost", p_params)
	title = "Fantasma"
	description = "Al reiniciar, tu intento anterior se repite como fantasma."


func setup(state) -> void:
	_load_ghost(state)


func on_restart(state) -> void:
	_load_ghost(state)


func _load_ghost(state) -> void:
	state.ghost_moves = PackedInt32Array()
	state.ghost_idx = 0
	state.ghost_active = not state.last_attempt.is_empty()
	state.ghost_pos = state.player_start
	for ch in state.last_attempt:
		var idx := GameState.DIR_CHARS.find(ch.to_lower())
		# 's' (twin switch) and unknowns burn a turn: keep the slot so
		# the replay stays in sync with the original attempt.
		state.ghost_moves.append(idx)


func state_key(state) -> String:
	return "gh:%s:%d" % [str(state.ghost_pos), state.ghost_idx]


func hud_lines(state) -> PackedStringArray:
	if state.ghost_active:
		return PackedStringArray([
			"Fantasma: %d movimientos restantes" % (state.ghost_moves.size() - state.ghost_idx)
		])
	return PackedStringArray(["Fantasma: aparecerá al reiniciar"])


static func describe() -> Dictionary:
	return {
		"title": "Fantasma",
		"description": "Al reiniciar el nivel, tu intento anterior se repite como un fantasma que también empuja cajas.",
	}


static func param_schema() -> Array:
	return []
