class_name CommunityRemote
extends RefCounted
## HTTP backend for the community feed — enabled when the setting
## `community_remote_url` is non-empty (Options → Comunidad → Servidor).
## Speaks JSON REST to server/community_server.py (or any compatible
## implementation). Everything is async; the local store in
## CommunityService stays the source of truth the UI reads, remote
## pushes are fire-and-forget.
##
## Auth: register/login return a Bearer token kept in
## `community_remote_token` (user:// — local to this device). Publish
## and like REQUIRE it server-side; play/clear stay anonymous.


static func url() -> String:
	return str(Storage.get_setting("community_remote_url", "")).strip_edges()


static func enabled() -> bool:
	return url() != ""


static func token() -> String:
	return str(Storage.get_setting("community_remote_token", ""))


static func username() -> String:
	return str(Storage.get_setting("community_remote_user", ""))


static func logged_in() -> bool:
	return token() != ""


static func _request(method: HTTPClient.Method, path: String,
		body: Variant, cb: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var req := HTTPRequest.new()
	req.timeout = 8.0
	tree.root.add_child.call_deferred(req)
	req.request_completed.connect(func(result, code, _h, b):
		req.queue_free()
		var parsed = JSON.parse_string(b.get_string_from_utf8())
		# sesión caducada o token rechazado estando logueados →
		# limpiar la sesión local; el siguiente intento pedirá login
		if code == 401 and token() != "":
			logout()
		cb.call({"ok": result == HTTPRequest.RESULT_SUCCESS
			and code >= 200 and code < 300, "code": code,
			"body": parsed}))
	var headers := ["Content-Type: application/json"]
	if token() != "":
		headers.append("Authorization: Bearer " + token())
	var payload := "" if body == null else JSON.stringify(body)
	req.request.call_deferred(url().rstrip("/") + path, headers, method, payload)


## GET /api/feed → cb({"ok", "entries": [...]})
static func pull_feed(cb: Callable) -> void:
	_request(HTTPClient.METHOD_GET, "/api/feed", null, func(r):
		var ents: Array = []
		if r["ok"] and r["body"] is Dictionary:
			var v: Variant = r["body"].get("entries", [])
			if v is Array:
				ents = v
		cb.call({"ok": r["ok"], "entries": ents}))


## POST /api/register|login → cb({"ok", "body":{token,username}})
## On success the session persists in settings for future launches.
static func auth(action: String, user: String, password: String,
		cb: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/api/" + action,
		{"username": user, "password": password}, func(r):
			if r.get("ok", false) and r.get("body") is Dictionary:
				var b: Dictionary = r["body"]
				Storage.set_setting("community_remote_token",
					str(b.get("token", "")))
				Storage.set_setting("community_remote_user",
					str(b.get("username", user)))
			cb.call(r))


static func logout() -> void:
	Storage.set_setting("community_remote_token", "")
	Storage.set_setting("community_remote_user", "")


## El servidor asigna el autor desde la sesión — el campo del
## payload se ignora (nadie publica en nombre de otro). Se adjunta la
## solución del playtest (`moves`): el servidor la rejuega y marca
## `verified`, o rechaza niveles vanilla cuya solución no cierra.
static func publish(level: LevelData, cb: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/api/publish", {
		"title": level.title,
		"data": level.to_dict(),
		"rules": level.rules.map(func(r): return str(r.get("id", ""))),
		"moves": "".join(Storage.get_replay_moves(level)),
		"difficulty": level.difficulty, "par": level.par},
		cb)


## play/clear: contadores anónimos fire-and-forget.
static func bump(action: String, remote_id: String) -> void:
	_request(HTTPClient.METHOD_POST, "/api/" + action,
		{"id": remote_id}, func(_r): pass)


## like: toggle autenticado — cb recibe {"ok", "body":{liked,likes}}.
static func like(remote_id: String, cb: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/api/like",
		{"id": remote_id}, cb)


static func remove(remote_id: String, token: String) -> void:
	_request(HTTPClient.METHOD_POST, "/api/remove",
		{"id": remote_id, "token": token}, func(_r): pass)
