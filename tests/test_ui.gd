extends SceneTree
## Headless UI smoke test:
## godot --headless --path . -s res://tests/test_ui.gd

var failures := 0


func _initialize() -> void:
	Storage.BASE_DIR = "user://devin_test/"
	DirAccess.make_dir_recursive_absolute("user://devin_test")
	var dd := DirAccess.open("user://devin_test")
	if dd:
		for fn in dd.get_files():
			dd.remove(fn)
	_run.call_deferred()


func ok(cond: bool, name: String) -> void:
	if cond:
		print("  ok: " + name)
	else:
		failures += 1
		printerr("  FAIL: " + name)


func _run() -> void:
	print("== UI smoke test ==")
	var main: Control = load("res://scripts/main.gd").new()
	root.add_child(main)
	await process_frame
	ok(main.current is MenuScreen, "menu shown")

	main.show_level_select()
	await process_frame
	ok(main.current is LevelSelectScreen, "level select shown")

	main.show_editor()
	await process_frame
	ok(main.current is EditorScreen, "editor shown")

	var ed: EditorScreen = main.current
	# editor QoL: stroke/undo/redo/mirror
	ed.begin_stroke()
	ed.paint_cell(Vector2i(1, 1), false)
	ok(ed.cells.get(Vector2i(1, 1)) == "#", "editor stroke paints")
	ed._editor_undo()
	ok(not ed.cells.has(Vector2i(1, 1)), "editor undo restores")
	ed._editor_redo()
	ok(ed.cells.get(Vector2i(1, 1)) == "#", "editor redo restores")
	ed.mirror_x = true
	ed._stamp(Vector2i(1, 2), false)
	ok(ed.cells.has(Vector2i(ed.grid_w - 2, 2)), "mirror X paints both sides")
	ed.mirror_x = false
	ed.cells.clear()
	ed._undo_stack.clear()
	ed._redo_stack.clear()
	ed.paint_cell(Vector2i(2, 2), false)  # tool=# -> wall
	ed.cells[Vector2i(3, 3)] = "@"
	ed.cells[Vector2i(4, 3)] = "$"
	ed.cells[Vector2i(5, 3)] = "."
	# mutar las reglas invalida la solución verificada (el botón
	# «Ver solución» no debe reproducir la del tablero anterior)
	ed._solution = PackedStringArray(["u"])
	ed.b_play_sol.visible = true
	ed._add_rule("ice", {})
	ok(not ed.b_play_sol.visible, "add_rule invalidates verified solution")
	var l := ed.build_level()
	ok(l != null and l.validate().is_empty(), "editor builds valid level")
	ok(l.rules.size() == 1 and l.rules[0]["id"] == "ice", "editor attaches rule")
	var code := l.to_code()
	ok(LevelData.from_code(code) != null, "editor level encodes")

	main.show_game(Campaign.levels()[2])
	await process_frame
	var gs: GameScreen = main.current
	ok(gs.state != null, "game state built")
	ok(gs.state.rules.size() == 1, "ice rule loaded")
	gs._move(Vector2i(1, 0))
	gs._move(Vector2i(1, 0))
	await process_frame
	ok(gs.state.boxes[0] == Vector2i(7, 2), "ice slide through UI input path")
	gs._solve()
	var frames := 0
	while gs._solving and frames < 600:
		await process_frame
		frames += 1
	ok(not gs.autoplay.is_empty(), "solver autoplay queued")

	main.show_map()
	await process_frame
	ok(main.current is MapScreen, "map screen shown")
	ok((main.current as MapScreen).nodes.size() >= 200, "map has level nodes")

	main.show_import()
	await process_frame
	ok(main.current is ImportScreen, "import screen shown")

	main.show_stats()
	await process_frame
	ok(main.current is StatsScreen, "stats screen shown")

	main.show_controls()
	await process_frame
	var cs: ControlsScreen = main.current
	ok(cs is ControlsScreen, "controls screen shown")
	cs._capturing = "undo"
	var kev := InputEventKey.new()
	kev.keycode = KEY_M
	kev.pressed = true
	cs._unhandled_input(kev)
	ok(int(Storage.get_setting("key_undo", KEY_Z)) == KEY_M, "rebind persisted")
	Storage.set_setting("key_undo", KEY_Z)

	main.show_options()
	await process_frame
	ok(main.current is OptionsScreen, "options screen shown")

	main.show_generator()
	await process_frame
	ok(main.current is GeneratorScreen, "generator screen shown")

	# async guard: generar y salir a mitad — el callback diferido no
	# debe tocar la pantalla liberada ni saltar a una partida
	var gs_gen: GeneratorScreen = main.current
	gs_gen.seed_edit.text = "7"
	gs_gen._go()
	ok(gs_gen._b_go.disabled, "generating disables go")
	main.show_menu()  # la swap libera la pantalla aunque el worker siga
	await process_frame
	var wait_frames := 0
	while wait_frames < 600:
		await process_frame
		wait_frames += 1
		if main.current is MenuScreen:
			break
	ok(main.current is MenuScreen,
		"late generation callback doesn't hijack the screen")

	# board skin: flat hides sprites; restore afterwards
	Storage.set_setting("board_skin", 1)
	BoardView.reload_skin()
	ok(BoardView.tex("box") == null, "flat skin hides sprites")
	Storage.set_setting("board_skin", 0)
	BoardView.reload_skin()

	# select-type rule params render and write back
	var ed2 := EditorScreen.new(main)
	root.add_child(ed2)
	ed2._add_rule("wind", {})
	var e2: Dictionary = ed2.rule_entries.back()
	ok(e2["controls"]["dir"]["value"] == 0, "select param default")
	e2["controls"]["dir"]["value"] = 2  # OptionButton would pick ↓
	var wl := ed2.build_level()
	ok(wl.rules[0]["params"]["dir"] == 2, "select param serializes")
	ed2.queue_free()

	main.show_community()
	await process_frame
	var comm: CommunityScreen = main.current
	ok(comm is CommunityScreen, "community screen shown")
	ok(not comm._list.get_children().is_empty(), "community has seeded levels")
	var first_row := comm._list.get_children()[0]
	ok(first_row is PanelContainer, "community row built")

	# E2E comunidad con backend REAL: publish→sync→dedup→remove contra
	# server/community_server.py levantado aquí (se salta sin python)
	await _community_remote_e2e()

	main.show_menu()
	await process_frame
	ok(main.current is MenuScreen, "back to menu")

	print("== UI smoke: %d failures ==" % failures)
	quit(1 if failures > 0 else 0)


## Espera a que una promesa del ciclo remoto resuelva (frames, no sleeps).
func _wait_until(cond: Callable, frames := 240) -> bool:
	var f := 0
	while not cond.call() and f < frames:
		await process_frame
		f += 1
	return cond.call()


func _community_remote_e2e() -> void:
	var port := 18923
	var srv := ProjectSettings.globalize_path("res://server/community_server.py")
	# OS.execute BLOQUEA hasta que el proceso muere — para un servidor
	# hay que usar create_process (no bloqueante, devuelve pid).
	# --db a un fichero temporal: el test no debe tocar community.db real
	var test_db := ProjectSettings.globalize_path(
		"user://devin_test/e2e_community.db")
	DirAccess.remove_absolute(test_db)
	var pid := OS.create_process("python",
		PackedStringArray([srv, "--port", str(port), "--db", test_db]))
	if pid <= 0:
		print("  skip: community e2e (python no disponible)")
		return
	Storage.set_setting("community_remote_url", "http://127.0.0.1:%d" % port)
	# poll /health hasta que el servidor escuche (espera real: los
	# frames headless corren mucho más rápido que el arranque de python)
	var up := false
	for i in 40:
		var r := HTTPRequest.new()
		r.timeout = 1.5
		root.add_child(r)
		r.request("http://127.0.0.1:%d/api/health" % port)
		var done_r := {}
		r.request_completed.connect(func(_res, code, _h, _b):
			done_r["code"] = code
			r.queue_free())
		await _wait_until(func(): return done_r.has("code"))
		if done_r.get("code", 0) == 200:
			up = true
			break
		await create_timer(0.15).timeout
	ok(up, "e2e: servidor comunitario arranca")
	if not up:
		OS.kill(pid)
		Storage.set_setting("community_remote_url", "")
		return
	# register → Bearer token en settings (publish/like lo exigen)
	var adone := {}
	CommunityRemote.auth("register", "e2e_tester", "pw1234",
		func(r): adone["v"] = r.get("ok", false))
	await _wait_until(func(): return adone.has("v"))
	ok(adone.get("v", false), "e2e: registro devuelve token Bearer")
	ok(CommunityRemote.logged_in(), "e2e: sesión persistida")
	# publish sin login → 401 (el Bearer es obligatorio)
	var noauth := {}
	var r401 := HTTPRequest.new()
	r401.timeout = 2.0
	root.add_child(r401)
	r401.request_completed.connect(func(_res, code, _h, _b):
		noauth["code"] = code; r401.queue_free())
	r401.request("http://127.0.0.1:%d/api/publish" % port,
		["Content-Type: application/json"], HTTPClient.METHOD_POST,
		"{\"title\":\"x\",\"data\":{\"board\":\"#####\\n#@$.#\\n#####\"}}")
	await _wait_until(func(): return noauth.has("code"))
	ok(noauth.get("code", 0) == 401, "e2e: publish anónimo → 401")
	# publish → remote_id/token persistidos tras el POST.
	# El nivel "#####/#@$.#/#####" se resuelve con un empuje "r" —
	# record_win deja el replay que viaja como `moves` (verified=1).
	var lvl := LevelData.create("E2E", PackedStringArray([
		"#####", "#@$.#", "#####"]), [], "dev")
	Storage.record_win(lvl, PackedStringArray(["r"]), 1.0)
	var pr := CommunityService.publish(lvl, "dev")
	ok(pr.get("ok", false), "e2e: publish local ok")
	var pid_local: String = pr["id"]
	var got_remote: bool = await _wait_until(func():
		var e: Variant = CommunityService._catalog()["entries"].get(pid_local)
		return e != null and str(e.get("remote_id", "")) != "")
	ok(got_remote, "e2e: publish remoto devuelve id+token")
	# sync → el feed remoto llega, pero el propio nivel NO se duplica
	var done := {}
	CommunityService.sync_remote(func(r): done["v"] = r.get("ok", false))
	await _wait_until(func(): return done.has("v"))
	ok(done.get("v", false), "e2e: sync remote ok")
	var cat: Dictionary = CommunityService._catalog()
	var re: Dictionary = cat.get("remote_entries", {})
	var dup := false
	for rid in re.keys():
		for e in cat["entries"].values():
			if str(e.get("remote_id", "")) == str(rid):
				dup = true
	ok(not dup, "e2e: la publicación propia no se duplica en el feed")
	# like remoto: el servidor reconcilia liked/likes (toggle por cuenta)
	var ldone := {}
	var rid0 := ""
	for e in cat["entries"].values():
		if str(e.get("remote_id", "")) != "":
			rid0 = str(e["remote_id"])
	CommunityRemote.like(rid0, func(r):
		ldone["v"] = (r.get("ok", false)
			and r.get("body", {}).get("liked") == true))
	await _wait_until(func(): return ldone.has("v"))
	ok(ldone.get("v", false), "e2e: like autenticado → liked+likes reales")
	# solución falsa → el servidor rejuega y rechaza (unsolved)
	var fake := {}
	var r422 := HTTPRequest.new()
	r422.timeout = 2.0
	root.add_child(r422)
	r422.request_completed.connect(func(_res, code, _h, _b):
		fake["code"] = code; r422.queue_free())
	var fake_body := "{\"title\":\"fake\",\"data\":{\"board\":\"#####\\n#@$.#\\n#####\"},\"moves\":\"llll\"}"
	r422.request("http://127.0.0.1:%d/api/publish" % port,
		["Content-Type: application/json",
		"Authorization: Bearer " + CommunityRemote.token()],
		HTTPClient.METHOD_POST, fake_body)
	await _wait_until(func(): return fake.has("code"))
	ok(fake.get("code", 0) == 422,
		"e2e: solución inválida → 422 unsolved")
	# sesión caducada en el servidor → 401 token_expired y el cliente
	# cierra sesión local automáticamente
	OS.execute("python", PackedStringArray(["-c",
		("import sqlite3; c=sqlite3.connect(r'%s');" % test_db) +
		"c.execute('UPDATE sessions SET expires=1'); c.commit()"]))
	var ex := {}
	CommunityRemote.like(rid0, func(r): ex["code"] = r.get("code", 0))
	await _wait_until(func(): return ex.has("code"))
	ok(ex.get("code", 0) == 401, "e2e: sesión caducada → 401")
	ok(not CommunityRemote.logged_in(),
		"e2e: 401 limpia la sesión local")
	# re-login para poder borrar como propietario
	adone = {}
	CommunityRemote.auth("login", "e2e_tester", "pw1234",
		func(r): adone["v"] = r.get("ok", false))
	await _wait_until(func(): return adone.has("v"))
	ok(adone.get("v", false), "e2e: re-login tras caducidad")
	# remove → borra local + remoto (con token)
	CommunityService.remove(pid_local)
	await _wait_until(func():
		return not CommunityService._catalog()["entries"].has(pid_local), 30)
	ok(not cat["entries"].has(pid_local), "e2e: remove borra la entrada local")
	OS.kill(pid)
	CommunityRemote.logout()
	Storage.set_setting("community_remote_url", "")
