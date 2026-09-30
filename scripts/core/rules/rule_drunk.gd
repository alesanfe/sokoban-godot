class_name DrunkRule
extends SokobanRule
## Mareo: cada movimiento gira tu dirección 90° en sentido horario —
## el primer paso va donde dices, el segundo va girado… El contador
## vive en rule_state, así que deshacer/replay respetan la secuencia.


func _init(p_params: Dictionary = {}) -> void:
	super("drunk", p_params)
	title = "Mareo"
	description = "Cada paso gira tu dirección %d°." % (90 * int(p_params.get("step", 1)))


func setup(state) -> void:
	state.rule_state[id] = {"n": 0}


func remaps_move() -> bool:
	return true


func remap_move(state, dir: Vector2i) -> Vector2i:
	# solo lee el contador: after_turn lo incrementa, así el snapshot del
	# turno captura el valor previo y deshacer/replay son consistentes
	var n: int = int(state.rule_state.get(id, {}).get("n", 0)) \
		* int(params.get("step", 1))
	var d := dir
	for i in n % 4:
		d = Vector2i(-d.y, d.x)  # 90° horario en coords de pantalla (y↓)
	return d


func after_turn(state) -> void:
	var rs: Dictionary = state.rule_state.get(id, {"n": 0})
	rs["n"] = int(rs.get("n", 0)) + 1
	state.rule_state[id] = rs


func state_key(state) -> String:
	return "drunk:%d" % int(state.rule_state.get(id, {}).get("n", 0))


func hud_lines(state) -> PackedStringArray:
	var n := int(state.rule_state.get(id, {}).get("n", 0))
	return PackedStringArray(["Mareo: próximo paso girado %d°" % (
		90 * n * int(params.get("step", 1)) % 360)])


static func describe() -> Dictionary:
	return {
		"title": "Mareo",
		"description": "Cada paso gira tu dirección de movimiento 90° (acumulativo).",
	}


static func param_schema() -> Array:
	return [
		{"key": "step", "label": "Giro por paso (×90°)", "type": "select",
			"options": ["90°", "180°", "270°"], "values": [1, 2, 3],
			"default": 1},
	]
