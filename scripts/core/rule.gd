class_name SokobanRule
extends RefCounted
## Base class for the "absurd rules". Each rule is a plugin that hooks
## into the turn pipeline of GameState. Rules must be deterministic and
## operate only on GameState data so that undo, replays and the solver
## behave identically.

var id: String = ""
var title: String = ""
var description: String = ""
var params: Dictionary = {}


func _init(p_id: String = "", p_params: Dictionary = {}) -> void:
	id = p_id
	params = p_params


## Called once when a level starts (and after restart). Use it to
## initialize state.rule_state[id].
func setup(_state) -> void:
	pass


## Return false to forbid pushing this box in this direction.
func can_push(_state, _box_idx: int, _dir: Vector2i) -> bool:
	return true


## Return true if this rule takes over push destination resolution.
func overrides_push() -> bool:
	return false


## Resolves where a pushed box ends up. Only called if overrides_push().
## Return Vector2i(-1, -1) if the push is impossible.
func resolve_push(state, box_idx: int, dir: Vector2i) -> Vector2i:
	var dest: Vector2i = state.boxes[box_idx] + dir
	if state.is_free_for_box(dest):
		return dest
	return Vector2i(-1, -1)


## Return false to forbid this box MOVING at all this turn — applies to
## every displaced box (chain members, bond clusters, drags), not just
## the pushed head like can_push. Push budgets veto here.
func can_move(_state, _box_idx: int, _dir: Vector2i) -> bool:
	return true


## Called once per consumed turn before any position changes — rules
## that react to "boxes that stayed put" (link) snapshot here.
func before_move(_state, _dir: Vector2i) -> void:
	pass


## Called right after a successful push.
func after_push(_state, _box_idx: int, _dir: Vector2i) -> void:
	pass


## Called for every box actually displaced by a push (head, chain
## members, bond cluster, drags) — push budgets charge here.
func after_box_moved(_state, _box_idx: int, _dir: Vector2i) -> void:
	pass


## Return true if this rule wants to rewrite the player's move
## direction (drunkenness, reversed controls…).
func remaps_move() -> bool:
	return false


## Called before a move is resolved; return the direction the player
## ACTUALLY moves in. Must be deterministic (store counters in
## state.rule_state so undo/replay behave).
func remap_move(_state, dir: Vector2i) -> Vector2i:
	return dir


## UI-layer input transform (inverted/rotated controls). Unlike
## remap_move this never enters the engine: move_log stores the raw
## input and the solver stays in logical space.
func transform_input(_state, dir: Vector2i) -> Vector2i:
	return dir


## Called on level restart (after setup). E.g. ghost rule loads the
## previous attempt here.
func on_restart(_state) -> void:
	pass


## String fragment identifying this rule's mutable data, appended to
## GameState.canonical_key() for solver dedupe.
func state_key(_state) -> String:
	return ""


## Called after the player has moved (and pushed) but before after_turn.
func after_player_move(_state, _dir: Vector2i, _pushed: bool) -> void:
	pass


## Called at the end of every consumed turn.
func after_turn(_state) -> void:
	pass


## Called after ALL resolvers (bombs/holes/pits/swaps/switches) and the
## solved check — win/lose rules must evaluate the final board here so
## rule order can't decide last-turn wins.
func on_turn_end(_state) -> void:
	pass


## Called when box `idx` is removed (bomb, hole, pit, life…): index-keyed
## rule_state must drop that entry to stay aligned with state.boxes.
func on_box_removed(_state, _idx: int) -> void:
	pass


## Called after a snapshot restore / JSON deserialize so the rule can
## repair degraded types in state.rule_state[id] (e.g. PackedInt32Array
## coming back as a plain Array).
func fix_state(_state) -> void:
	pass


## Win-condition override: return true/false to replace the default
## "all goals covered" check; return null to keep the default.
func win_check(_state):
	return null


## Short lines shown in the HUD so the player understands the rule.
func hud_lines(_state) -> PackedStringArray:
	var lines := PackedStringArray()
	if title != "":
		lines.append(title)
	return lines


static func param_schema() -> Array:
	## [{key, label, type:"int"|"float"|"bool", min, max, default}]
	return []


static func describe() -> Dictionary:
	return {"title": "", "description": ""}
