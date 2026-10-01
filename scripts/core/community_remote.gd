class_name CommunityRemote
extends RefCounted
## HTTP backend for the community feed — enabled when the setting
## `community_remote_url` is non-empty (Options → Comunidad → Servidor).
## Speaks JSON REST to server/community_server.py (or any compatible
## implementation). Everything is async; the local store in
## CommunityService stays the source of truth the UI reads, remote
## pushes are fire-and-forget.


static func url() -> String:
	return str(Storage.get_setting("community_remote_url", "")).strip_edges()


static func enabled() -> bool:
	return url() != ""


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
		cb.call({"ok": result == HTTPRequest.RESULT_SUCCESS
			and code >= 200 and code < 300, "code": code,
			"body": parsed}))
	var headers := ["Content-Type: application/json"]
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


static func publish(level: LevelData, author: String, cb: Callable) -> void:
	_request(HTTPClient.METHOD_POST, "/api/publish", {
		"title": level.title, "author": author,
		"data": level.to_dict(),
		"rules": level.rules.map(func(r): return str(r.get("id", ""))),
		"difficulty": level.difficulty, "par": level.par},
		cb)


static func bump(action: String, remote_id: String) -> void:
	_request(HTTPClient.METHOD_POST, "/api/" + action,
		{"id": remote_id}, func(_r): pass)


static func remove(remote_id: String, token: String) -> void:
	_request(HTTPClient.METHOD_POST, "/api/remove",
		{"id": remote_id, "token": token}, func(_r): pass)
