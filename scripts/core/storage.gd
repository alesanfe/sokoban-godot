class_name Storage
extends RefCounted
## Persistence: custom levels, best scores and replays in user://.

const LEVELS_PATH := "user://custom_levels.json"
const PROGRESS_PATH := "user://progress.json"
const SETTINGS_PATH := "user://settings.json"

## Defaults centrales: la UI puede llamar get_setting(key) sin fallback.
## (Las teclas key_* llevan su default en ControlsScreen.DEFAULTS.)
const SETTING_DEFAULTS := {
	"ui_theme": "dark", "board_skin": 0,
	"music": true, "music_vol": 70, "sfx": true,
	"show_moves": true, "show_timer": true, "show_par": true,
	"deadlock_assist": 2, "confirm_restart": false,
	"reduce_motion": false, "repeat_rate": 0.11, "autoplay_speed": 1.0,
}

## Versión de esquema de los JSON persistidos: save_json la estampa en
## los dicts raíz. Los archivos sin "v" son esquema 1 — el día que el
## formato cambie, las migraciones se enganchan en load_json según v.
const SCHEMA_V := 2

## JSON parseado por ruta; save_json lo mantiene coherente con el disco.
static var _cache := {}

## Prefijo de los paths user:// — los tests lo apuntan a un subdir
## propio para no pisar (ni leer) los datos reales del jugador.
static var BASE_DIR := "user://"


## Resuelve un path lógico: si empieza por user:// lo reprefija con
## BASE_DIR; cualquier otro path pasa intacto.
static func _p(path: String) -> String:
	return BASE_DIR + path.substr(7) if path.begins_with("user://") else path


static func load_json(path: String, fallback) -> Variant:
	var rp := _p(path)
	if _cache.has(rp):
		return _cache[rp]
	var out = fallback
	if FileAccess.file_exists(rp):
		var f := FileAccess.open(rp, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			# raíz del tipo esperado: un JSON válido pero de otro tipo
			# (p.ej. `[1]` donde se espera un objeto) rompería los
			# `var x: Dictionary`/`Array` de los consumidores
			if parsed != null and typeof(parsed) == typeof(fallback):
				out = parsed
	_cache[rp] = out
	return out


static func save_json(path: String, data) -> void:
	if data is Dictionary:
		data["v"] = SCHEMA_V
	var rp := _p(path)
	_cache[rp] = data
	var f := FileAccess.open(rp, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


# ------------------------------------------------------------- levels

static func custom_levels() -> Array:
	var out: Array = []
	var raw: Array = load_json(LEVELS_PATH, [])
	for d in raw:
		if typeof(d) == TYPE_DICTIONARY:
			out.append(LevelData.from_dict(d))
	return out


## Clave por contenido (misma convención que CommunityService.id_for):
## un nivel ajeno con el mismo título ya no pisa uno del usuario.
static func save_custom_level(level: LevelData) -> void:
	var raw: Array = load_json(LEVELS_PATH, [])
	var d := level.to_dict()
	var id := LevelData.id_for(level)
	d["id"] = id
	var replaced := false
	for i in raw.size():
		if typeof(raw[i]) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = raw[i]
		# entradas antiguas sin id: mismo nivel si título y tablero coinciden
		var same: bool = str(e.get("id", "")) == id \
				or (not e.has("id") and e.get("title", "") == d["title"] \
					and e.get("board", "") == d["board"])
		if same:
			raw[i] = d
			replaced = true
	if not replaced:
		raw.append(d)
	save_json(LEVELS_PATH, raw)


## Borra por id de contenido (misma clave que save_custom_level); las
## entradas antiguas sin id se casan por título+tablero.
static func delete_custom_level(level: LevelData) -> void:
	var id := LevelData.id_for(level)
	var bkey := "\n".join(level.board)
	var raw: Array = load_json(LEVELS_PATH, [])
	raw = raw.filter(func(d):
		if typeof(d) != TYPE_DICTIONARY:
			return true
		if d.has("id"):
			return str(d["id"]) != id
		return not (d.get("title", "") == level.title
			and str(d.get("board", "")) == bkey))
	save_json(LEVELS_PATH, raw)


# ----------------------------------------------------------- progress

static func _progress() -> Dictionary:
	return load_json(PROGRESS_PATH, {"best": {}, "replays": {}})


## Progress keys use content_code (board+rules) so renaming a level or
## editing its metadata no longer orphans its best/replay records. Old
## to_code-keyed entries stay readable via a fallback lookup.
static func record_win(level: LevelData, moves: PackedStringArray, elapsed: float = 0.0) -> Dictionary:
	var p := _progress()
	var key := level.content_code()
	var old_key := level.to_code()
	var best: Dictionary = p.get("best", {})
	var prev: Variant = best.get(key)
	if prev == null:
		prev = best.get(old_key)
	var prev_moves := 0
	var prev_time := 0.0
	if prev is Dictionary:
		prev_moves = int(prev.get("m", 0))
		prev_time = float(prev.get("t", 0.0))
	elif prev != null:
		prev_moves = int(prev)
	var new_best := prev == null or moves.size() < prev_moves \
		or (moves.size() == prev_moves and (prev_time <= 0.0 or elapsed < prev_time))
	if new_best:
		best[key] = {"m": moves.size(), "t": elapsed}
	var replays: Dictionary = p.get("replays", {})
	var cur: String = replays.get(key, "")
	if cur == "":
		cur = replays.get(old_key, "")
	if cur == "" or moves.size() < cur.length() or new_best:
		replays[key] = "".join(moves)
	p["best"] = best
	p["replays"] = replays
	save_json(PROGRESS_PATH, p)
	return {"new_best": new_best, "prev_moves": prev_moves}


static func best_moves(level: LevelData) -> int:
	var best: Dictionary = _progress().get("best", {})
	var e: Variant = best.get(level.content_code())
	if e == null:
		e = best.get(level.to_code())  # legacy keys
	if e is Dictionary:
		return int(e.get("m", 0))
	return int(e) if e != null else 0


static func best_time(level: LevelData) -> float:
	var best: Dictionary = _progress().get("best", {})
	var e: Variant = best.get(level.content_code())
	if e == null:
		e = best.get(level.to_code())
	return float(e.get("t", 0.0)) if e is Dictionary else 0.0


static func get_replay_moves(level: LevelData) -> PackedStringArray:
	var replays: Dictionary = _progress().get("replays", {})
	var s: String = str(replays.get(level.content_code(),
		replays.get(level.to_code(), "")))
	var out := PackedStringArray()
	for i in s.length():
		out.append(s[i])
	return out


static func mark_daily() -> void:
	var p := _progress()
	var days: Dictionary = p.get("daily_days", {})
	# misma convención UTC (yyyymmdd) que daily_streak/_date_seed
	days[_date_seed(Time.get_unix_time_from_system())] = true
	p["daily_days"] = days
	save_json(PROGRESS_PATH, p)


static func daily_streak() -> int:
	var days: Dictionary = _progress().get("daily_days", {})
	var streak := 0
	var t := Time.get_unix_time_from_system()
	if not days.has(_date_seed(t)):  # today may still be pending
		t -= 86400
	while days.has(_date_seed(t)):
		streak += 1
		t -= 86400
	return streak


static func daily_total() -> int:
	return _progress().get("daily_days", {}).size()


static func _date_seed(unix: float) -> String:
	var d := Time.get_date_dict_from_unix_time(int(unix))
	return str(int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"]))


# -------------------------------------------------- publish clearance

## Mario Maker rule: you must beat your own level before publishing it.
## Playtest wins are recorded by content hash (board+rules), so renaming
## the level or editing metadata doesn't invalidate a legit playtest.
static func mark_playtested(code: String) -> void:
	var p := _progress()
	var tested: Dictionary = p.get("playtested", {})
	var key := code
	var l := LevelData.from_code(code)
	if l != null:
		key = l.content_code()
	tested[key.sha256_text().substr(0, 16)] = true
	p["playtested"] = tested
	save_json(PROGRESS_PATH, p)


static func is_playtested(level: LevelData) -> bool:
	var tested: Dictionary = _progress().get("playtested", {})
	return tested.has(level.content_code().sha256_text().substr(0, 16))


# -------------------------------------------------- in-progress save

static func save_in_progress(level: LevelData, state: GameState) -> void:
	save_json("user://in_progress.json", {
		"level": level.to_dict(),
		"state": state.serialize(),
		"saved_at": int(Time.get_unix_time_from_system()),
	})


static func get_in_progress() -> Variant:
	var d: Dictionary = load_json("user://in_progress.json", {})
	if d.is_empty() or typeof(d.get("state")) != TYPE_DICTIONARY \
			or not d["state"].has("snap"):
		return null
	if not d.has("level"):
		return null
	var l := LevelData.from_dict(d.get("level", {}))
	if l.board.is_empty() or l.board[0].is_empty():
		return null
	return {"level": l, "state": d["state"]}


static func clear_in_progress() -> void:
	save_json("user://in_progress.json", {})


# -------------------------------------------------- lifetime counters

static func bump_total(key: String, amount: int = 1) -> void:
	var p := _progress()
	var t: Dictionary = p.get("totals", {})
	t[key] = int(t.get(key, 0)) + amount
	p["totals"] = t
	save_json(PROGRESS_PATH, p)


static func totals() -> Dictionary:
	return _progress().get("totals", {})


# ----------------------------------------------------------- settings

## Rangos admitidos: un settings.json editado a mano (o corrupto) no
## debe colar valores absurdos — repeat_rate=0 movería cada frame.
const SETTING_CLAMP := {
	"repeat_rate": [0.03, 1.0],
	"autoplay_speed": [0.25, 8.0],
	"music_vol": [0, 100],
	"deadlock_assist": [0, 3],
	"board_skin": [0, 2],
}

static func get_setting(key: String, fallback: Variant = null) -> Variant:
	if fallback == null:
		fallback = SETTING_DEFAULTS.get(key)
	var v = load_json(SETTINGS_PATH, {}).get(key, fallback)
	if SETTING_CLAMP.has(key) and (v is float or v is int):
		var r: Array = SETTING_CLAMP[key]
		v = clampf(float(v), float(r[0]), float(r[1]))
	return v


static func set_setting(key: String, value: Variant) -> void:
	var s: Dictionary = load_json(SETTINGS_PATH, {})
	s[key] = value
	save_json(SETTINGS_PATH, s)
