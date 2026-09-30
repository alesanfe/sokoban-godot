class_name PushLimitRule
extends SokobanRule
## Solo puedes empujar cada caja un número limitado de veces.


func _init(p_params: Dictionary = {}) -> void:
	super("push_limit", p_params)
	var m: int = int(p_params.get("max", 2))
	title = "Empuje limitado"
	description = "Cada caja solo puede empujarse %d veces." % m


func setup(state) -> void:
	state.rule_state[id] = {"counts": PackedInt32Array()}


func _counts(state) -> PackedInt32Array:
	# JSON round-trips degrade PackedInt32Array to Array — normalize.
	var raw = state.rule_state.get(id, {}).get("counts", PackedInt32Array())
	var c: PackedInt32Array = raw if raw is PackedInt32Array else PackedInt32Array(raw)
	if c.size() != state.boxes.size():
		c.resize(state.boxes.size())
	state.rule_state[id]["counts"] = c
	return c


## Counts are indexed by box slot: when a box is removed the survivors
## shift left, so drop the dead box's budget to keep them aligned.
func on_box_removed(state, idx: int) -> void:
	var c := _counts(state)
	if idx < c.size():
		c.remove_at(idx)
		state.rule_state[id]["counts"] = c


func can_push(state, box_idx: int, _dir: Vector2i) -> bool:
	var c := _counts(state)
	return box_idx < c.size() and c[box_idx] < int(params.get("max", 2))


## Mid-chain / bond-cluster members can't sneak in extra moves either.
func can_move(state, box_idx: int, _dir: Vector2i) -> bool:
	return can_push(state, box_idx, _dir)


## Charge every displaced box, not just the pushed head.
func after_box_moved(state, box_idx: int, _dir: Vector2i) -> void:
	var c := _counts(state)
	if box_idx < c.size():
		c[box_idx] += 1


func pushes_left(state, box_idx: int) -> int:
	return int(params.get("max", 2)) - _counts(state)[box_idx]


func state_key(state) -> String:
	var c: PackedInt32Array = _counts(state)
	var parts := PackedStringArray()
	for v in c:
		parts.append(str(v))
	return "pl:" + ",".join(parts)


func hud_lines(state) -> PackedStringArray:
	var c: PackedInt32Array = _counts(state)
	var remaining := PackedStringArray()
	for i in c.size():
		remaining.append(str(int(params.get("max", 2)) - c[i]))
	return PackedStringArray([
		"Empujes restantes: %s" % "/".join(remaining),
	])


static func describe() -> Dictionary:
	return {
		"title": "Empuje limitado",
		"description": "Cada caja solo puede empujarse N veces en total.",
	}


static func param_schema() -> Array:
	return [
		{"key": "max", "label": "Empujes máximos por caja", "type": "int", "min": 1, "max": 10, "default": 2},
	]
