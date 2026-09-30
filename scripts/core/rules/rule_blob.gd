class_name BlobRule
extends SokobanRule
## Amontonar (estilo Interlock): se gana cuando TODAS las cajas forman
## un único bloque ortogonalmente conexo — los objetivos no cuentan.


func _init(p_params: Dictionary = {}) -> void:
	super("blob", p_params)
	title = "Amontonar"
	description = "Gana cuando todas las cajas se tocan formando un solo grupo."


func win_check(state):
	if state.boxes.is_empty():
		return false
	if params.get("per_color", false):
		# Interlock puro: cada color debe formar su propio bloque.
		var by_color := {}
		for i in state.boxes.size():
			var ci := int(state.box_colors[i]) if i < state.box_colors.size() else 0
			if not by_color.has(ci):
				by_color[ci] = []
			by_color[ci].append(i)
		for ci in by_color.keys():
			if not _connected(state, by_color[ci]):
				return false
		return true
	return _connected(state, range(state.boxes.size()))


func _connected(state, members) -> bool:
	var seen := {members[0]: true}
	var stack: Array = [members[0]]
	var allowed := {}
	for m in members:
		allowed[m] = true
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for d in GameState.DIRS.values():
			var bi: int = state.box_at(state.boxes[i] + d)
			if bi != -1 and allowed.has(bi) and not seen.has(bi):
				seen[bi] = true
				stack.append(bi)
	return seen.size() == members.size()


func hud_lines(_state) -> PackedStringArray:
	if params.get("per_color", false):
		return PackedStringArray(["Amontonar: cada color en su propio bloque"])
	return PackedStringArray(["Amontonar: junta todas las cajas en un solo bloque"])


static func describe() -> Dictionary:
	return {
		"title": "Amontonar",
		"description": "Se gana cuando todas las cajas forman un bloque conexo (los objetivos no cuentan).",
	}


static func param_schema() -> Array:
	return [{"key": "per_color", "label": "Un bloque por cada color",
		"type": "bool", "default": false}]
