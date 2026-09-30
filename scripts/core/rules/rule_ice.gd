class_name SlideRule
extends SokobanRule
## Las cajas se deslizan hasta chocar con algo.


func _init(p_params: Dictionary = {}) -> void:
	super("ice", p_params)
	title = "Hielo"
	description = "Las cajas se deslizan hasta chocar."


func overrides_push() -> bool:
	return true


func resolve_push(state, box_idx: int, dir: Vector2i) -> Vector2i:
	var cur: Vector2i = state.boxes[box_idx]
	var guard: int = state.width * state.height * 2 + 8
	var nxt: Vector2i = state.box_step_dest(cur, dir)
	while nxt != Vector2i(-1, -1) and guard > 0:
		cur = nxt
		nxt = state.box_step_dest(cur, dir)
		guard -= 1
	if guard <= 0:
		return Vector2i(-1, -1)  # portal/torus slide cycle: treat as blocked
	return cur if cur != state.boxes[box_idx] else Vector2i(-1, -1)


## Optional "jugador patina": the player keeps sliding after a walk move
## until a wall/box stops them (SokobanOnline modern ice).
func after_player_move(state, dir: Vector2i, pushed: bool) -> void:
	if pushed or not params.get("player_slide", false):
		return
	var guard: int = state.width * state.height * 2 + 8
	while guard > 0:
		guard -= 1
		var nxt: Vector2i = state.player + dir
		if state.is_solid(nxt) or state.has_box(nxt) or state.filters.has(nxt) \
				or state.twins.has(nxt) \
				or (state.ghost_active and state.ghost_pos == nxt):
			break
		# slide over the exit portal once, then stop on it
		var has_portal: bool = state._rule_on("portal") and state.portals.has(nxt)
		var dest: Vector2i = state.portals[nxt] if has_portal else nxt
		if dest != nxt and (state.is_solid(dest) or state.has_box(dest)
				or state.twins.has(dest)
				or (state.ghost_active and state.ghost_pos == dest)):
			dest = nxt
			has_portal = false
		state.player = dest
		if state.hole_cells.has(state.player):
			state.lost = true
			state.lost_reason = "Patín sobre hielo… directo al agujero."
			break
		if not has_portal:
			continue
		break  # teleported or portal landed: stop sliding
	state._pickup_key()


func hud_lines(state) -> PackedStringArray:
	if params.get("player_slide", false):
		return PackedStringArray(["Hielo: cajas y jugador se deslizan"])
	return PackedStringArray(["Hielo: las cajas se deslizan"])


static func describe() -> Dictionary:
	return {
		"title": "Hielo",
		"description": "Las cajas se deslizan hasta chocar con un obstáculo.",
	}


static func param_schema() -> Array:
	return [{"key": "player_slide", "label": "El jugador también patina",
		"type": "bool", "default": false}]
