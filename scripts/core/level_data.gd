class_name LevelData
extends RefCounted
## A level: board in extended XSB + active rules + metadata.
##
## Extended XSB chars (on top of the standard @ + $ * # . space/-):
##   &  mimic box        %  mimic box on goal
##   ?  peekaboo wall (solid only while the player looks at it)
##   !  rule switch      o/O  paired portals    > < ^ v  conveyor belts
##   k  key              K  door (consumes a key, blocks boxes)
##   x  bomb (box detonates on it, both vanish)
##   1-4 one-way gates (exit only →↓←↑)   b/c/d colored boxes, B/C/D matching goals
##
## Share code: "SKM1.<json_len>.<base64url(deflate(json))>"

const CODE_PREFIX := "SKM1."
## Sane caps for share codes coming from outside (paste/import):
## nobody shares a >64 KB level, and decompress() trusts `size`.
const MAX_CODE_LEN := 200_000
const MAX_DECOMPRESSED := 4_000_000
const MAX_BOARD_CELLS := 10_000
const MAX_PACK_LEVELS := 200       # tope de niveles en un código SKM2
const MAX_XSB_INPUT := 200_000     # tope del texto XSB pegado/importado
const MAX_XSB_SECTIONS := 64       # tope de secciones por archivo .sok
const MAX_RLE_CELLS := MAX_BOARD_CELLS * 4  # tope global de expansión RLE

var title: String = "Sin título"
var author: String = ""
var board: PackedStringArray = PackedStringArray()
var rules: Array = []  # [{id: String, params: Dictionary}]
var difficulty: int = 0  # 0 = unrated, 1-5 stars
var par: int = 0         # solver's move count (0 = unknown)
var hidden_rules: bool = false  # player must discover the rules


func set_meta_difficulty(d: int) -> void:
	difficulty = d


static func create(p_title: String, p_board: PackedStringArray, p_rules: Array = [], p_author: String = "") -> LevelData:
	var l := LevelData.new()
	l.title = p_title
	l.board = p_board
	l.rules = p_rules
	l.author = p_author
	return l


func to_dict() -> Dictionary:
	var rs := []
	for r in rules:
		rs.append({"id": r.get("id", ""), "params": r.get("params", {})})
	return {
		"v": 1,
		"title": title,
		"author": author,
		"board": "\n".join(board),
		"rules": rs,
		"diff": difficulty,
		"par": par,
		"hidden": hidden_rules,
	}


static func from_dict(d: Dictionary) -> LevelData:
	var l := LevelData.new()
	l.title = str(d.get("title", "Sin título"))
	l.author = str(d.get("author", ""))
	l.board = PackedStringArray(str(d.get("board", "")).split("\n"))
	# rules llega de JSON externo: solo {id: String, params: Dictionary}
	var raw_rules = d.get("rules", [])
	if typeof(raw_rules) == TYPE_ARRAY:
		for r in raw_rules:
			if typeof(r) != TYPE_DICTIONARY \
					or typeof(r.get("id")) != TYPE_STRING:
				continue
			var params = r.get("params", {})
			l.rules.append({"id": r["id"],
				"params": params if typeof(params) == TYPE_DICTIONARY else {}})
	l.difficulty = int(d.get("diff", 0))
	l.par = int(d.get("par", 0))
	l.hidden_rules = bool(d.get("hidden", false))
	return l


func to_code() -> String:
	var json := JSON.stringify(to_dict())
	var raw := json.to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var b64 := Marshalls.raw_to_base64(packed)
	b64 = b64.replace("+", "-").replace("/", "_").replace("=", "")
	return "%s%d.%s" % [CODE_PREFIX, raw.size(), b64]


## Serializa solo el contenido jugable (tablero + reglas): renombrar el
## nivel o tocar metadatos no cambia este código. Base de los hashes de
## playtest y de las claves de contenido en Storage.
var _ccache := ""
func content_code() -> String:
	# board/rules no se mutan tras create()/from_dict() — los cambios de
	# metadatos (título, par, dificultad) no afectan al contenido jugable.
	if _ccache == "":
		var d := to_dict()
		_ccache = JSON.stringify({"board": d["board"], "rules": d["rules"]})
	return _ccache


## Id estable por contenido: republicar el mismo nivel actualiza la ficha.
static func id_for(level: LevelData) -> String:
	return level.to_code().sha256_text().substr(0, 12)


static func from_code(code: String) -> LevelData:
	code = code.strip_edges()
	if not code.begins_with(CODE_PREFIX) or code.length() > MAX_CODE_LEN:
		return null
	var parsed = _decode_payload(code.substr(CODE_PREFIX.length()))
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return from_dict(parsed)


## Pack code: "SKM2.<json_len>.<base64url(deflate(json))>" where json is
## {"pack": [level dicts]}. One code shares a whole collection.
static func pack_code(levels: Array) -> String:
	var dicts := []
	for l in levels:
		dicts.append(l.to_dict())
	var json := JSON.stringify({"pack": dicts})
	var raw := json.to_utf8_buffer()
	var b64 := Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))
	b64 = b64.replace("+", "-").replace("/", "_").replace("=", "")
	return "SKM2.%d.%s" % [raw.size(), b64]


## Returns LevelData for SKM1, Array[LevelData] for SKM2, null if invalid.
static func decode(code: String) -> Variant:
	code = code.strip_edges()
	if code.begins_with("SKM2."):
		if code.length() > MAX_CODE_LEN:
			return null
		var parsed = _decode_payload(code.substr(5))
		if typeof(parsed) != TYPE_DICTIONARY \
				or typeof(parsed.get("pack")) != TYPE_ARRAY:
			return null
		var out: Array = []
		for d in (parsed["pack"] as Array).slice(0, MAX_PACK_LEVELS):
			if typeof(d) == TYPE_DICTIONARY:
				out.append(from_dict(d))
		return out
	return from_code(code)


static func _decode_payload(rest: String) -> Variant:
	var dot := rest.find(".")
	if dot == -1:
		return null
	var size := int(rest.substr(0, dot))
	if size <= 0 or size > MAX_DECOMPRESSED:
		return null  # declared length is bogus or a decompression bomb
	var b64 := rest.substr(dot + 1).replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var packed := Marshalls.base64_to_raw(b64)
	var raw := packed.decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return null
	return JSON.parse_string(raw.get_string_from_utf8())


func validate() -> PackedStringArray:
	## Returns a list of problems; empty = level is playable in principle.
	var problems := PackedStringArray()
	var cells := 0
	for line in board:
		cells += line.length()
	if cells > MAX_BOARD_CELLS:
		problems.append("Tablero demasiado grande (%d celdas; máx %d)" % [cells, MAX_BOARD_CELLS])
		return problems
	var players := 0
	var box_count := 0
	var goal_count := 0
	var portals := {"o": 0, "O": 0}
	var belts := 0
	var keys := 0
	var doors := 0
	var twins := 0
	var filters := {}   # índices de color con filtro presente
	var cboxes := {}   # colored box counts per color idx
	var cgoals := {}   # colored goal counts per color idx
	var bad := {}
	for line in board:
		for ch in line:
			var sp := TileSpec.spec(ch)
			if sp.is_empty():
				bad[ch] = true
				continue
			if sp.get("player", false):
				players += 1
			if sp.get("box", false):
				box_count += 1
			if sp.get("goal", false):
				goal_count += 1
			if int(sp.get("bcolor", 0)) > 0:
				var cb: String = "bcd"[int(sp["bcolor"]) - 1]
				cboxes[cb] = int(cboxes.get(cb, 0)) + 1
			if int(sp.get("gcolor", 0)) > 0:
				var cg: String = "bcd"[int(sp["gcolor"]) - 1]
				cgoals[cg] = int(cgoals.get(cg, 0)) + 1
			if sp.has("portal"):
				portals[ch] += 1
			if sp.has("conveyor"):
				belts += 1
			if sp.get("key", false):
				keys += 1
			if sp.get("door", false):
				doors += 1
			if sp.get("twin", false):
				twins += 1
			if sp.has("filter"):
				filters["bcd"[int(sp["filter"]) - 1]] = true
	if players == 0:
		problems.append("Falta el jugador (@)")
	if players > 1:
		problems.append("Hay más de un jugador")
	if twins > 8:
		problems.append("Demasiados gemelos (p): máximo 8")
	for ci in filters.keys():
		if int(cboxes.get(ci, 0)) == 0:
			problems.append("Filtro '%s' sin cajas '%s' que lo atraviesen" % [
				"EGH"["bcd".find(ci)], ci])
	# mitosis/life create boxes at runtime — starting counts may differ
	var box_mutating := _rule_ids().has("mitosis") or _rule_ids().has("life")
	if box_count == 0 and not box_mutating:
		problems.append("No hay cajas")
	if box_count < goal_count and not box_mutating:
		problems.append("Faltan cajas (%d) para los objetivos (%d)" % [box_count, goal_count])
	elif box_count != goal_count and not (has_bombs() or has_holes() or has_pits() or box_mutating) \
			and not _rule_ids().has("blob") and not _rule_ids().has("quota"):
		problems.append("Cajas (%d) y objetivos (%d) no coinciden" % [box_count, goal_count])
	for r2 in rules:
		if str(r2.get("id", "")) == "quota":
			var qn := int(r2.get("params", {}).get("n", 1))
			if qn > goal_count:
				problems.append("La cuota (%d) supera los objetivos (%d): irresoluble" % [
					qn, goal_count])
	if portals["o"] % 2 == 1 or portals["O"] % 2 == 1:
		problems.append("Portales sin pareja (o/O deben ir de dos en dos)")
	if doors > 0 and keys == 0:
		problems.append("Hay puertas pero ninguna llave (k)")
	# símbolos no reconocidos por el motor (detectados en el bucle)
	for ch in bad.keys():
		problems.append("Símbolo desconocido: '%s'" % ch)
	# conectividad: todo el suelo interior debe ser alcanzable
	# (se tratan ?, K, x, h, f, 1-4 como transitables a efectos de diseño)
	if problems.is_empty():
		problems.append_array(_connectivity_problems())
	# cajas aparcadas en casillas muertas (solo tableros clásicos):
	# en clásico nunca se arrastran — una caja muerta = nivel irresoluble
	if problems.is_empty():
		var s := GameState.from_level_data(self)
		if SokobanSolver.is_classic_state(s):
			var dead := SokobanSolver.dead_cells(s)
			var dead_boxes := 0
			for b in s.boxes:
				if dead.has(b) and not s.goals.has(b):
					dead_boxes += 1
			if dead_boxes > 0:
				problems.append("%d caja(s) empiezan en casillas muertas" % dead_boxes)
	for ci in cboxes.keys():
		if int(cboxes[ci]) != int(cgoals.get(ci, 0)):
			problems.append("Cajas color %s (%d) y objetivos %s (%d) no coinciden" % [
				ci, cboxes[ci], ci.to_upper(), int(cgoals.get(ci, 0))])
	var rids := _rule_ids()
	if portals["o"] + portals["O"] > 0 and not rids.has("portal"):
		problems.append("Hay portales pero falta la regla «Portales»")
	if belts > 0 and not rids.has("conveyor"):
		problems.append("Hay cintas pero falta la regla «Cintas»")
	var known := RuleRegistry.all_ids()
	for r in rids:
		if not known.has(r):
			problems.append("Regla desconocida: «%s»" % r)
	# un interruptor sin reglas solo conmuta una bandera vacía
	var switches := 0
	for line in board:
		switches += line.count("!")
	if switches > 0 and rids.is_empty():
		problems.append("Hay interruptores (!) pero ninguna regla que activar")
	return problems


## Structural check: flood-fill from the player over non-wall cells;
## reports boxes/goals isolated in sealed pockets or unreachable areas.
func _connectivity_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	var w := 0
	for line in board:
		w = maxi(w, line.length())
	var start := Vector2i(-1, -1)
	for y in board.size():
		var x := board[y].find("@")
		if x == -1:
			x = board[y].find("+")
		if x != -1:
			start = Vector2i(x, y)
			break
	if start == Vector2i(-1, -1):
		return problems
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= w or n.y >= board.size():
				continue
			var line: String = board[n.y]
			var ch: String = line[n.x] if n.x < line.length() else " "
			# filters block the player (only matching-color boxes pass)
			if TileSpec.blocks_player(ch):
				continue
			seen[n] = true
			stack.append(n)
	# Boxes already on a goal (* % a e i) are fine in sealed pockets —
	# they are solved. j/l/m are colored boxes on a neutral goal: they
	# still owe their own-color goal, so seal = unsolvable.
	var isolated_boxes := 0
	var isolated_goals := 0
	for y in board.size():
		for x in mini(board[y].length(), w):
			var ch := board[y][x]
			if TileSpec.is_box(ch) and not TileSpec.is_satisfied_box(ch) \
					and not seen.has(Vector2i(x, y)):
				isolated_boxes += 1
			if TileSpec.is_goal(ch) and not TileSpec.is_box(ch) \
					and not seen.has(Vector2i(x, y)):
				isolated_goals += 1
	if isolated_boxes > 0:
		problems.append("%d caja(s) en zonas inaccesibles" % isolated_boxes)
	if isolated_goals > 0:
		problems.append("%d objetivo(s) en zonas inaccesibles" % isolated_goals)
	return problems


func has_peekaboo() -> bool:
	for line in board:
		if line.contains("?"):
			return true
	return false


func has_switches() -> bool:
	for line in board:
		if line.contains("!"):
			return true
	return false


func has_portals() -> bool:
	for line in board:
		if line.contains("o") or line.contains("O"):
			return true
	return false


func has_conveyors() -> bool:
	for line in board:
		if line.contains(">") or line.contains("<") or line.contains("^") or line.contains("v"):
			return true
	return false


func has_doors() -> bool:
	for line in board:
		if line.contains("K") or line.contains("k"):
			return true
	return false


func _rule_ids() -> Array:
	var out: Array = []
	for r in rules:
		out.append(r.get("id", ""))
	return out


func has_bombs() -> bool:
	for line in board:
		if line.contains("x"):
			return true
	return false


func has_oneway() -> bool:
	for line in board:
		for ch in "1234":
			if line.contains(ch):
				return true
	return false


func has_colors() -> bool:
	for line in board:
		for ch in line:
			var sp := TileSpec.spec(ch)
			if int(sp.get("bcolor", 0)) > 0 or int(sp.get("gcolor", 0)) > 0:
				return true
	return false


func has_holes() -> bool:
	for line in board:
		if line.contains("h") or line.contains("f"):
			return true
	return false


func has_rails() -> bool:
	for line in board:
		if line.contains("=") or line.contains(":"):
			return true
	return false


func has_pits() -> bool:
	for line in board:
		if line.contains("u"):
			return true
	return false


## Parse raw XSB text (possibly RLE-compressed: "4#|# @$.#|3#") into
## LevelData entries — splits sections on blank lines like .sok files.
## RLE expands only digit-runs followed by board chars, so our 1-4
## one-way tiles in plain pasted boards stay literal.
static func from_xsb_text(text: String) -> Array:
	if text.length() > MAX_XSB_INPUT:
		return []
	var sections := PackedStringArray()
	var cur := PackedStringArray()
	for line in text.split("\n"):
		if line.strip_edges() == "":
			if not cur.is_empty():
				sections.append("\n".join(cur))
				cur.clear()
		else:
			cur.append(line)
	if not cur.is_empty():
		sections.append("\n".join(cur))
	var out: Array = []
	for sec in sections.slice(0, MAX_XSB_SECTIONS):
		var lines := _expand_rle(sec, sec.contains("|")) if _looks_rle(sec) \
				else PackedStringArray(sec.split("\n"))
		var l := create("Importado", lines)
		if l.validate().is_empty():
			out.append(l)
	return out


static func _looks_rle(text: String) -> bool:
	if text.contains("|"):
		return true
	# Unambiguous RLE only: our 1-4 one-way tiles are digits too, so a
	# lone 1-4 before a board char stays literal — only multi-digit runs
	# or digits 5-9/0 mark compression.
	var run := 0
	for i in text.length() - 1:
		var c := text[i]
		if c >= "0" and c <= "9":
			run += 1
			var n := text[i + 1]
			if (run >= 2 or c >= "5" or c == "0") and n in "#. @*$+-_|":
				return true
		else:
			run = 0
	return false


static func _expand_rle(text: String, force: bool = false) -> PackedStringArray:
	text = text.replace("|", "\n")
	var lines := PackedStringArray()
	var total := 0  # celdas expandidas acumuladas: corta la amplificación
	for raw in text.split("\n"):
		var row := ""
		var digits := ""
		for i in raw.length():
			var c := raw[i]
			if c >= "0" and c <= "9":
				digits += c
				continue
			# A lone 1-4 digit is our one-way tile unless the section was
			# '|'-separated (unambiguous RLE).
			var literal_14 := not force and digits.length() == 1 \
					and digits >= "1" and digits <= "4"
			if digits.is_empty():
				row += c
			elif literal_14:
				row += digits + c
				digits = ""
			elif c in "#. @*$+-_":
				var n := mini(int(digits), MAX_BOARD_CELLS)
				if total + n > MAX_RLE_CELLS:
					return lines
				row += c.repeat(n)
				total += n
				digits = ""
			else:
				row += digits + c  # digit was literal (our 1-4 tiles etc.)
				digits = ""
		if not digits.is_empty():
			row += digits
		lines.append(row)
	return lines


static func empty_board(w: int, h: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for y in h:
		var row := ""
		for x in w:
			row += "#" if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else " "
		lines.append(row)
	return lines
