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
	ed._add_rule("ice", {})
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

	main.show_menu()
	await process_frame
	ok(main.current is MenuScreen, "back to menu")

	print("== UI smoke: %d failures ==" % failures)
	quit(1 if failures > 0 else 0)
