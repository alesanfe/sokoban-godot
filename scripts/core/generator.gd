class_name LevelGenerator
extends RefCounted
## Procedural generator: random-walk room carving + reverse-pull
## scrambling, which guarantees solvability by construction. Every
## candidate is still verified with the real solver (respecting rules).
##
## daily_seed() produces a stable seed per calendar day.

const MAX_ATTEMPTS := 40

## Rules that do nothing on a generated board: it only emits classic
## tiles (@ $ . #), so tile-/marker-dependent or degenerate rules would
## be advertised but inert.
const INERT_ON_GENERATED := ["portal", "conveyor", "mimic",
	"two_players", "quota", "torus"]


static func daily_seed() -> int:
	# UTC, igual que Storage._date_seed: la racha diaria y el desafío
	# comparten calendario sin depender de la zona horaria local.
	var d := Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system()))
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


static func generate(seed: int, w: int = 10, h: int = 8, n_boxes: int = 3, rule_id: String = "") -> LevelData:
	var rng := RandomNumberGenerator.new()
	for attempt in MAX_ATTEMPTS:
		rng.seed = seed + attempt * 7919
		var level := _try_generate(rng, w, h, n_boxes, rule_id)
		if level == null:
			continue
		var res := SokobanSolver.solve(level, 25000)
		if res.get("ok", false) and res.get("moves", []).size() >= 8:
			level.set_meta_difficulty(SokobanSolver.rate_difficulty(res, level))
			return level
	return null


static func daily() -> LevelData:
	var seed := daily_seed()
	var ids := RuleRegistry.all_ids()
	ids = PackedStringArray(Array(ids).filter(
		func(r): return not INERT_ON_GENERATED.has(r)))
	# deterministic rule choice per day
	var rule_id := ids[seed % ids.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + 7
	var w := 9 + rng.randi_range(0, 3)
	var h := 8 + rng.randi_range(0, 2)
	var nb := 3 + rng.randi_range(0, 1)
	var level := generate(seed, w, h, nb, rule_id)
	if level == null:
		level = generate(seed + 1, w, h, nb, "")
	if level:
		var d := Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system()))
		level.title = "Desafío diario %04d-%02d-%02d" % [d["year"], d["month"], d["day"]]
	return level


static func _try_generate(rng: RandomNumberGenerator, w: int, h: int, n_boxes: int, rule_id: String) -> LevelData:
	# --- carve room: all walls, random walk digs floor
	var floor := {}
	var pos := Vector2i(w / 2, h / 2)
	floor[pos] = true
	var target := int(w * h * 0.45)
	var steps := 0
	while floor.size() < target and steps < w * h * 40:
		steps += 1
		var d: Vector2i = GameState.DIRS.values()[rng.randi_range(0, 3)]
		var np := pos + d
		if np.x < 1 or np.y < 1 or np.x > w - 2 or np.y > h - 2:
			continue
		pos = np
		floor[pos] = true
	var cells := floor.keys()
	if cells.size() < n_boxes * 3 + 4:
		return null

	# --- choose distinct cells: player, goals
	# shuffle with our rng for determinism (sin shuffle() global: rompería
	# la reproducibilidad por semilla)
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	var player: Vector2i = cells[0]
	var goal_cells: Array = cells.slice(1, 1 + n_boxes)
	var boxes: Array = goal_cells.duplicate()  # boxes start ON goals

	# --- scramble with reverse pulls (guarantees solvable)
	var p := player
	var scramble := w * h * 6
	for i in scramble:
		var d: Vector2i = GameState.DIRS.values()[rng.randi_range(0, 3)]
		var fwd := p + d
		var behind := p - d
		if not floor.has(fwd):
			continue
		var bi := boxes.find(behind)
		if bi != -1:
			# pull: player steps to fwd, box at behind moves into p
			if not floor.has(behind) or boxes.has(fwd):
				continue
			boxes[bi] = p
			p = fwd
		elif not boxes.has(fwd):
			p = fwd
	# make sure boxes actually moved off goals
	var moved := 0
	for b in boxes:
		if not goal_cells.has(b):
			moved += 1
	if moved == 0:
		return null

	# --- build board
	var lines := PackedStringArray()
	for y in h:
		var row := ""
		for x in w:
			var c := Vector2i(x, y)
			if not floor.has(c):
				row += "#"
			elif c == p:
				row += "+" if goal_cells.has(c) else "@"
			elif boxes.has(c):
				row += "*" if goal_cells.has(c) else "$"
			elif goal_cells.has(c):
				row += "."
			else:
				row += " "
		lines.append(row)
	var rules := []
	if rule_id != "":
		rules.append({"id": rule_id, "params": _default_params(rule_id)})
	var level := LevelData.create("Generado", lines, rules, "Máquina")
	return level


static func _default_params(rule_id: String) -> Dictionary:
	var out := {}
	for spec in RuleRegistry.param_schema(rule_id):
		out[spec["key"]] = spec.get("default")
	return out
