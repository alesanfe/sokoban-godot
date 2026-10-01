class_name CommunityService
extends RefCounted
## Catálogo de niveles publicados ("Modo Comunidad", estilo Mario Maker).
##
## Dos fuentes conviven en user://community.json:
##   entries        → publicaciones locales (offline)
##   remote_entries → espejo del feed remoto (si hay backend configurado
##                    en Ajustes → `community_remote_url`; ver
##                    server/community_server.py). Sus contadores viven
##                    en el servidor; el espejo solo guarda `liked`.
##
## Entrada: {id, level: Dictionary(LevelData), author, ts, likes,
##           plays, clears, liked, own, remote_id?}
## Las ids remotas se exponen prefijadas "r:<rid>".
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
	# publicar también al backend si hay uno configurado — la ficha
	# local recuerda su remote_id para likes/removes posteriores
	if CommunityRemote.enabled():
		var lvl := level
		var auth: String = entries[id]["author"]
		CommunityRemote.publish(lvl, auth, func(r):
			if r.get("ok", false):
				_mutate(id, func(e): e["remote_id"] = str(r["body"].get("id", ""))))
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
	# espejo remoto: ids "r:<rid>"; los contadores son los del servidor
	for rid in cat.get("remote_entries", {}).keys():
		var e: Variant = cat["remote_entries"][rid]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var l := LevelData.from_dict(e.get("level", {}))
		out.append({"id": "r:" + str(rid), "level": l,
			"author": str(e.get("author", "")),
			"ts": int(e.get("ts", 0)),
			"likes": int(e.get("likes", 0)),
			"plays": int(e.get("plays", 0)),
			"clears": int(e.get("clears", 0)),
			"liked": bool(e.get("liked", false)),
			"own": false})
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


## ¿id remota ("r:<rid>")? Devuelve el rid o "".
static func _rid(id: String) -> String:
	return id.substr(2) if id.begins_with("r:") else ""


static func _remote_mutate(rid: String, fn: Callable) -> void:
	var cat := _catalog()
	var re: Dictionary = cat.get("remote_entries", {})
	if not re.has(rid):
		return
	fn.call(re[rid])
	_save(cat)


static func like(id: String) -> bool:
	var now := false
	var rid := _rid(id)
	if rid != "":
		# servidor: solo sube al dar like (no hay unlike) — el toggle
		# local ajusta la vista; el conteo es aproximado como en el feed
		_remote_mutate(rid, func(e):
			e["liked"] = not bool(e.get("liked", false))
			e["likes"] = maxi(0, int(e.get("likes", 0)) + (1 if e["liked"] else -1))
			now = e["liked"])
		if now and CommunityRemote.enabled():
			CommunityRemote.bump("like", rid)
		return now
	_mutate(id, func(e):
		e["liked"] = not bool(e.get("liked", false))
		e["likes"] = maxi(0, int(e.get("likes", 0)) + (1 if e["liked"] else -1))
		now = e["liked"])
	if now and CommunityRemote.enabled():
		var rid2 := str(_catalog()["entries"][id].get("remote_id", ""))
		if rid2 != "":
			CommunityRemote.bump("like", rid2)
	return now


static func record_play(id: String) -> void:
	var rid := _rid(id)
	if rid != "":
		_remote_mutate(rid, func(e): e["plays"] = int(e.get("plays", 0)) + 1)
		if CommunityRemote.enabled():
			CommunityRemote.bump("play", rid)
		return
	_mutate(id, func(e): e["plays"] = int(e.get("plays", 0)) + 1)


static func record_clear(id: String) -> void:
	var rid := _rid(id)
	if rid != "":
		_remote_mutate(rid, func(e): e["clears"] = int(e.get("clears", 0)) + 1)
		if CommunityRemote.enabled():
			CommunityRemote.bump("clear", rid)
		return
	_mutate(id, func(e): e["clears"] = int(e.get("clears", 0)) + 1)


static func remove(id: String) -> void:
	var cat := _catalog()
	var e: Variant = cat.get("entries", {}).get(id)
	var rid := "" if e == null else str(e.get("remote_id", ""))
	var author := "" if e == null else str(e.get("author", ""))
	cat.get("entries", {}).erase(id)
	_save(cat)
	if rid != "" and CommunityRemote.enabled():
		CommunityRemote.remove(rid, author)


## Sincroniza el feed remoto → espejo local. cb(recibe {"ok": bool}).
## Sin backend configurado devuelve ok=false inmediato.
static func sync_remote(cb: Callable) -> void:
	if not CommunityRemote.enabled():
		cb.call({"ok": false})
		return
	CommunityRemote.pull_feed(func(r):
		if r.get("ok", false):
			var cat := _catalog()
			merge_remote_feed(cat, r["entries"])
			_save(cat)
		cb.call({"ok": r.get("ok", false)}))


## Merge puro del feed del servidor → cat["remote_entries"]:
## preserva `liked` y NO espeja los rid ya cubiertos por una
## publicación local (remote_id) — sin esto el nivel propio salía
## dos veces en el feed. Testeable sin HTTP (runner).
static func merge_remote_feed(cat: Dictionary, remote: Array) -> void:
	var published := {}
	for e in cat.get("entries", {}).values():
		if typeof(e) == TYPE_DICTIONARY and e.get("remote_id"):
			published[str(e["remote_id"])] = true
	var prev: Dictionary = cat.get("remote_entries", {})
	var re := {}
	for e in remote:
		if typeof(e) != TYPE_DICTIONARY or not e.get("id"):
			continue
		var rid := str(e["id"])
		if published.has(rid):
			continue   # la entrada local ya representa esta publicación
		re[rid] = {
			"level": e.get("data", {}),
			"author": str(e.get("author", "")),
			"ts": int(e.get("ts", 0)),
			"likes": int(e.get("likes", 0)),
			"plays": int(e.get("plays", 0)),
			"clears": int(e.get("clears", 0)),
			"liked": bool(prev.get(rid, {}).get("liked", false)),
		}
	cat["remote_entries"] = re


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
