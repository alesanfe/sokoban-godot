class_name CommunityService
extends RefCounted
## Catálogo de niveles publicados ("Modo Comunidad", estilo Mario Maker).
##
## Hoy vive en user://community.json (offline). La API está diseñada
## como capa de servicio: list()/publish()/like()/record_* podrían
## apuntar a un backend HTTP sin tocar la UI.
##
## Entrada: {id, level: Dictionary(LevelData), author, ts, likes,
##           plays, clears, liked, own}
## Mario Maker rule: solo se publica un nivel que su autor ha superado.

const PATH := "user://community.json"

## Catálogo en memoria: entries() no relee/reparsea el JSON en cada
## llamada. El archivo sigue siendo la fuente de verdad en el primer
## acceso; _save lo invalida/actualiza en cada escritura.
static var _cache: Variant = null


static func _catalog() -> Dictionary:
	if _cache == null:
		_cache = Storage.load_json(PATH, {"entries": {}})
	return _cache


static func _save(cat: Dictionary) -> void:
	_cache = cat
	Storage.save_json(PATH, cat)


## Id estable por contenido: republicar el mismo nivel actualiza la ficha.
static func id_for(level: LevelData) -> String:
	return LevelData.id_for(level)


static func publish(level: LevelData, author: String) -> Dictionary:
	var problems := level.validate()
	if not problems.is_empty():
		return {"ok": false, "err": problems[0]}
	var cat := _catalog()
	var entries: Dictionary = cat.get("entries", {})
	var id := id_for(level)
	var prev: Dictionary = entries.get(id, {})
	entries[id] = {
		"level": level.to_dict(),
		"author": author if author != "" else "Anónimo",
		"ts": prev.get("ts", int(Time.get_unix_time_from_system())),
		"likes": int(prev.get("likes", 0)),
		"plays": int(prev.get("plays", 0)),
		"clears": int(prev.get("clears", 0)),
		"liked": bool(prev.get("liked", false)),
		"own": true,
	}
	cat["entries"] = entries
	_save(cat)
	return {"ok": true, "id": id}


static func entries(sort: String = "recent") -> Array:
	var cat := _catalog()
	var out: Array = []
	for id in cat.get("entries", {}).keys():
		var e: Variant = cat["entries"][id]
		if typeof(e) != TYPE_DICTIONARY:  # entrada corrupta → saltar
			continue
		var l := LevelData.from_dict(e.get("level", {}))
		out.append({"id": id, "level": l,
			"author": str(e.get("author", "")),
			"ts": int(e.get("ts", 0)),
			"likes": int(e.get("likes", 0)),
			"plays": int(e.get("plays", 0)),
			"clears": int(e.get("clears", 0)),
			"liked": bool(e.get("liked", false)),
			"own": bool(e.get("own", false))})
	match sort:
		"likes":
			out.sort_custom(func(a, b): return a["likes"] > b["likes"])
		"plays":
			out.sort_custom(func(a, b): return a["plays"] > b["plays"])
		"clears":
			out.sort_custom(func(a, b): return a["clears"] > b["clears"])
		_:
			out.sort_custom(func(a, b): return a["ts"] > b["ts"])
	return out


static func _mutate(id: String, fn: Callable) -> void:
	var cat := _catalog()
	var entries: Dictionary = cat.get("entries", {})
	if not entries.has(id):
		return
	fn.call(entries[id])
	_save(cat)


static func like(id: String) -> bool:
	var now := false
	_mutate(id, func(e):
		e["liked"] = not bool(e.get("liked", false))
		e["likes"] = maxi(0, int(e.get("likes", 0)) + (1 if e["liked"] else -1))
		now = e["liked"])
	return now


static func record_play(id: String) -> void:
	_mutate(id, func(e): e["plays"] = int(e.get("plays", 0)) + 1)


static func record_clear(id: String) -> void:
	_mutate(id, func(e): e["clears"] = int(e.get("clears", 0)) + 1)


static func remove(id: String) -> void:
	var cat := _catalog()
	cat.get("entries", {}).erase(id)
	_save(cat)


## Niveles semilla "oficiales" para que la comunidad no arranque vacía.
static func seed_officials() -> void:
	var cat := _catalog()
	if not cat.get("entries", {}).is_empty():
		return
	var seeds: Array = [
		["Jardín de bienvenida", [
			"##########",
			"#   .    #",
			"#   $    #",
			"#@  $   .#",
			"#   .    #",
			"##########"]],
		["Pista de hielo", [
			"##########",
			"#@       #",
			"# $      #",
			"#       .#",
			"##########"], "ice"],
		["La cinta", [
			"##########",
			"#@ $>>>. #",
			"##########"], "conveyor"],
		["El atajo", [
			"##########",
			"#@k K $ .#",
			"##########"]],
	]
	for i in seeds.size():
		var s: Array = seeds[i]
		var rules: Array = []
		if s.size() > 2:
			rules.append({"id": s[2], "params": {}})
		var l := LevelData.create(str(s[0]), PackedStringArray(s[1]), rules, "Equipo Sokoban")
		var cat_e: Dictionary = cat.get("entries", {})
		var id := id_for(l)
		cat_e[id] = {
			"level": l.to_dict(), "author": "Equipo Sokoban",
			"ts": 1700000000 + i * 86400,
			"likes": 4 + i * 3, "plays": 10 + i * 5, "clears": 6 + i * 2,
			"liked": false, "own": false,
		}
		cat["entries"] = cat_e
	_save(cat)
