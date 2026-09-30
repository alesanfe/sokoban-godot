class_name QuotaRule
extends SokobanRule
## Cuota: basta con cubrir N objetivos — las demás cajas/metas sobran.
## Análogo a las clear-conditions «recoge X» de Mario Maker.


func _init(p_params: Dictionary = {}) -> void:
	super("quota", p_params)
	title = "Cuota"
	var n: int = int(p_params.get("n", 1))
	description = "Basta con cubrir %d objetivo(s)." % n


## A goal only counts when covered by a box of the matching color
## (colored goals B/C/D reject wrong-colored boxes, like is_solved).
static func _covered(state) -> int:
	var n := 0
	for g in state.goals.keys():
		var bi: int = state.box_at(g)
		if bi == -1:
			continue
		var bcol: int = int(state.box_colors[bi]) if bi < state.box_colors.size() else 0
		if int(state.goal_colors.get(g, 0)) != bcol:
			continue
		n += 1
	return n


func win_check(state):
	var n: int = int(params.get("n", 1))
	return _covered(state) >= n


func hud_lines(state) -> PackedStringArray:
	var n: int = int(params.get("n", 1))
	return PackedStringArray(["Cuota: %d/%d objetivos cubiertos" % [_covered(state), n]])


static func describe() -> Dictionary:
	return {
		"title": "Cuota",
		"description": "Basta con cubrir N objetivos; el resto son decoración.",
	}


static func param_schema() -> Array:
	return [{"key": "n", "label": "Objetivos a cubrir", "type": "int",
		"min": 1, "max": 99, "default": 1}]
