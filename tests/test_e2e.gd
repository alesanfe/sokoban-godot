extends SceneTree
## TRUE end-to-end: boots the real main.tscn, injects real input events
## (key presses + mouse clicks) through the Viewport pipeline and plays
## the game like a human: menu → level select → level → arrows →
## undo → restart → solver button → autoplay win → back to menu.
##   godot --headless --path . -s res://tests/test_e2e.gd

var failures := 0
var checks := 0
var main: Control


func _initialize() -> void:
	Storage.BASE_DIR = "user://devin_test/"
	DirAccess.make_dir_recursive_absolute("user://devin_test")
	var dd := DirAccess.open("user://devin_test")
	if dd:
		for fn in dd.get_files():
			dd.remove(fn)
	_run.call_deferred()


func ok(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  ok: " + name)
	else:
		failures += 1
		printerr("  FAIL: " + name)


func _run() -> void:
	print("== E2E: real input, real scene ==")
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _settle()
	ok(main.current is MenuScreen, "boots to menu")

	# click "Jugar campaña" like a user
	var b := _find_button("Jugar campaña")
	ok(b != null, "menu button 'Jugar campaña' exists")
	await _click(b)
	ok(main.current is LevelSelectScreen, "click navigated to level select")

	# click the first campaign level card (label: "· 1. Primeros pasos")
	var lb := _find_button("Primeros pasos")
	ok(lb != null, "level 1 card clickable")
	await _click(lb)
	ok(main.current is GameScreen, "level opened")
	var gs: GameScreen = main.current
	var s0: Vector2i = gs.state.player

	# real arrow keys: level 1 needs U,L,L,D then R,R,R to win
	await _key(KEY_UP)
	await _key(KEY_LEFT)
	await _key(KEY_LEFT)
	await _key(KEY_DOWN)
	ok(gs.state.player != s0, "arrow keys moved the player")
	ok(gs.state.turn == 4, "4 moves consumed via key events")

	# click on-screen undo button twice (mouse path)
	await _click(_find_button("Deshacer"))
	await _click(_find_button("Deshacer"))
	ok(gs.state.turn == 2, "clicked undo twice")
	ok(gs.undos_used == 2, "undo counter incremented")

	# keyboard undo (keybind path)
	await _key(KEY_Z)
	ok(gs.state.turn == 1, "keybind Z undoes")

	# R restarts the level
	await _key(KEY_R)
	await _settle()
	ok(gs.state.turn == 0, "keybind R restarts")
	ok(gs.restarts_used == 1, "restart counter incremented")

	# click "Resolver" — async solver → autoplay → win panel
	await _click(_find_button("Resolver"))
	var frames := 0
	while gs._solving and frames < 900:
		await process_frame
		frames += 1
	ok(not gs.autoplay.is_empty(), "autoplay got a solution")
	while gs.state != null and not gs.state.solved and frames < 3000:
		await process_frame
		frames += 1
	ok(gs.state.solved, "autoplay won the level")
	await _settle()
	ok(gs.win_panel.visible, "win panel popped")

	# leave via the win panel's Menu button
	var bm := _find_button("Menú", gs.win_panel)
	await _click(bm)
	ok(main.current is MenuScreen, "exited to menu via win panel")

	print("== E2E: %d checks, %d failures ==" % [checks, failures])
	quit(1 if failures > 0 else 0)


# ------------------------------------------------------------ helpers

func _settle() -> void:
	for i in 4:
		await process_frame


## Synthetic key press+release through the real input pipeline.
func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	for i in 3:
		await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	for i in 2:
		await process_frame


## Synthetic mouse click on a Control's global center.
func _click(c: Control) -> void:
	if c == null:
		return
	var pos: Vector2 = c.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = pos
	down.global_position = pos
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = pos
	up.global_position = pos
	up.pressed = false
	Input.parse_input_event(up)
	for i in 3:
		await process_frame


## Depth-first search for a Button whose text contains `sub`.
func _find_button(sub: String, base: Node = null) -> Button:
	if base == null:
		base = main
	if base is Button and sub in (base as Button).text \
			and base.is_visible_in_tree():
		return base
	for ch in base.get_children():
		var r := _find_button(sub, ch)
		if r != null:
			return r
	return null


func _find_button_prefix(prefix: String, base: Node = null) -> Button:
	if base == null:
		base = main
	if base is Button and (base as Button).text.begins_with(prefix) \
			and base.is_visible_in_tree():
		return base
	for ch in base.get_children():
		var r := _find_button_prefix(prefix, ch)
		if r != null:
			return r
	return null
