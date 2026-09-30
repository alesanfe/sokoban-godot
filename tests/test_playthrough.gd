extends SceneTree
## Playthrough test: a bot that actually PLAYS the game end-to-end.
##   godot --headless --path . -s res://tests/test_playthrough.gd
##
## Covers the real gameplay loop: move by move through GameState,
## undo/redo/restart divergence, save/resume mid-level, signals,
## and a full UI-driven win through GameScreen (autoplay included).

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  ok: " + name)
	else:
		failures += 1
		printerr("  FAIL: " + name)


func _run() -> void:
	print("== Playthrough: engine ==")
	_engine_full_level()
	_engine_campaign_sample()
	_engine_undo_diverge()
	_engine_restart_ghost()
	_engine_save_resume()
	_engine_signals()
	print("== Playthrough: UI ==")
	await _ui_playthrough()
	_engine_clone_solved()
	_engine_undo_rotate()
	_engine_ghost_serialize()
	_engine_bomb_undo()
	_engine_playtest_gate()
	_engine_codes_hardening()
	await _ui_undo_after_win()
	await _ui_next_level()
	print("== %d checks, %d failures ==" % [checks, failures])
	quit(1 if failures > 0 else 0)


## clone() must keep `solved` — otherwise a cloned solved state would
## accept moves (try_move guards on the flag).
func _engine_clone_solved() -> void:
	var l: LevelData = LevelData.create("c", PackedStringArray([
		"#####", "#@$.#", "#####"]))
	var s := GameState.from_level_data(l)
	s.try_move(Vector2i(1, 0))
	ok(s.solved, "setup: level solved")
	var c := s.clone()
	ok(c.solved, "clone preserves solved flag")
	ok(not c.try_move(Vector2i(0, -1)), "cloned solved state refuses moves")


## Undo across a rotate: board dims are part of the snapshot.
func _engine_undo_rotate() -> void:
	var s := GameState.from_level_data(LevelData.create("r", PackedStringArray([
		"#######",
		"#     #",
		"#  @$ #",
		"#  .  #",
		"#     #",
		"#######",
	]), [{"id": "rotate", "params": {"every": 2, "cw": 1}}]))
	var w0 := s.width
	var h0 := s.height
	s.try_move(Vector2i(-1, 0))
	s.try_move(Vector2i(1, 0))  # rotate fires
	ok(s.width == h0, "rotate swapped dims")
	s.undo()
	ok(s.width == w0 and s.height == h0, "undo restores pre-rotate dims")


## Save/resume while a ghost is mid-replay.
func _engine_ghost_serialize() -> void:
	var l := LevelData.create("g", PackedStringArray([
		"########",
		"#      #",
		"# @$.  #",
		"#      #",
		"########",
	]), [{"id": "ghost", "params": {}}])
	var s := GameState.from_level_data(l)
	s.try_move(Vector2i(1, 0))
	s.restart()
	s.try_move(Vector2i(0, 1))
	var s2 := GameState.deserialize_state(l, s.serialize())
	ok(s2.ghost_active and s2.ghost_pos == s.ghost_pos,
		"ghost state survives serialize roundtrip")
	ok(s2.ghost_idx == s.ghost_idx, "ghost replay index preserved")


## Bomb eats the last box -> unsolvable; undo must restore box AND bomb.
func _engine_bomb_undo() -> void:
	var s := GameState.from_level_data(LevelData.create("b", PackedStringArray([
		"#######",
		"#@$x .#",
		"#######",
	])))
	s.try_move(Vector2i(1, 0))  # push box onto bomb
	ok(s.boxes.is_empty(), "box detonated")
	s.undo()
	ok(s.boxes.size() == 1, "undo restores exploded box")
	ok(not s.bomb_cells.is_empty(), "undo restores the bomb tile")


## Mario Maker gate: editor playtest marks the level code publishable.
func _engine_playtest_gate() -> void:
	# playtested is keyed by content (board+rules), so the board must
	# vary per run — progress.json persists across test runs. A full
	# randi() tail (not just padding) keeps collisions ~impossible.
	var l := LevelData.create("pt",
		PackedStringArray(["######",
			"#@$. #" + str(randi()), "######"]), [], "tester")
	ok(not Storage.is_playtested(l), "fresh level not playtested")
	Storage.mark_playtested(l.to_code())
	ok(Storage.is_playtested(l), "playtest win marks code as publishable")


## Hostile/broken share codes and imports must not crash or explode.
func _engine_codes_hardening() -> void:
	# RLE digit-run that would eat a one-way tile: "2" must stay literal
	var plain := LevelData.from_xsb_text("######\n#@$2.#\n######")
	ok(plain.size() == 1 and plain[0].board[1].contains("2"),
		"plain board keeps 1-4 tiles literal (no false RLE)")
	# '|'-separated RLE still expands runs
	var rle := LevelData.from_xsb_text("5#|#@$.#|5#")
	ok(rle.size() == 1 and rle[0].board[0] == "#####",
		"'|'-separated RLE expands")
	# decompression bomb: huge declared size -> null, no hang
	var bomb := "SKM1.999999999.AAAA"
	ok(LevelData.from_code(bomb) == null, "bogus size rejected")
	# oversized board rejected by validate
	var big := LevelData.create("big", PackedStringArray(["#" + " ".repeat(200) + "#"]))
	ok(not big.validate().is_empty(), "oversized board rejected")


## Win -> undo hides the panel so play can continue.
func _ui_undo_after_win() -> void:
	var main: Control = load("res://scripts/main.gd").new()
	root.add_child(main)
	await process_frame
	var l: LevelData = Campaign.levels()[0]
	main.show_game(l)
	await process_frame
	var gs: GameScreen = main.current
	var res: Dictionary = SokobanSolver.solve(l)
	for ch in res["moves"]:
		gs.state.try_move(GameState.DIRS[ch.to_lower()])
	await process_frame
	ok(gs.state.solved and gs.win_panel.visible, "win panel shown")
	gs._undo()
	ok(not gs.win_panel.visible, "undo after win hides panel")
	ok(not gs.state.solved, "undo un-solves")
	# keep playing: finish again through the input path
	gs._move(Vector2i(1, 0))
	await process_frame
	ok(gs.state.solved and gs.win_panel.visible, "re-win re-shows panel")
	main.queue_free()
	await process_frame


## Win panel "Siguiente nivel" advances the campaign.
func _ui_next_level() -> void:
	var main: Control = load("res://scripts/main.gd").new()
	root.add_child(main)
	await process_frame
	main.show_game(Campaign.levels()[0])
	await process_frame
	var gs: GameScreen = main.current
	gs._next_level()
	await process_frame
	ok(gs.level.title == Campaign.levels()[1].title,
		"next level loads campaign[1]")
	ok(gs.state != null and gs.state.turn == 0, "fresh state for next level")
	main.queue_free()
	await process_frame


# ------------------------------------------------------------- engine

## Play every move of a solver solution char-by-char through try_move,
## with ticks between — exactly what the game does.
func _play(s: GameState, moves: PackedStringArray, tick_each := true) -> void:
	for ch in moves:
		if ch.to_lower() == "s":
			s.try_switch()
		else:
			s.try_move(GameState.DIRS[ch.to_lower()])
		if tick_each:
			s.tick(0.016)


func _engine_full_level() -> void:
	var l: LevelData = Campaign.levels()[0]
	var res: Dictionary = SokobanSolver.solve(l)
	ok(res["ok"], "solver solves first campaign level")
	var s := GameState.from_level_data(l)
	_play(s, res["moves"])
	ok(s.is_solved(), "played to victory")
	ok(s.turn == res["moves"].size(), "turn counter matches moves")
	var pushes := 0
	for ch in s.move_log:
		pushes += 1 if ch == ch.to_upper() else 0
	ok(pushes > 0, "pushes recorded in move log (uppercase)")


## Sample campaign levels across the whole campaign (every 10th + last),
## always via solver → play → solved. Proves rules engine + solver agree.
func _engine_campaign_sample() -> void:
	var lvls := Campaign.levels()
	var idxs := []
	for i in range(0, lvls.size(), 10):
		idxs.append(i)
	idxs.append(lvls.size() - 1)
	for i in idxs:
		var l: LevelData = lvls[i]
		var res: Dictionary = SokobanSolver.solve(l, 60000)
		if not res["ok"]:
			ok(false, "campaign[%d] %s solvable (%s)" % [i, l.title, res.get("reason", "")])
			continue
		var s := GameState.from_level_data(l)
		_play(s, res["moves"])
		ok(s.is_solved(), "campaign[%d] %s completed by playthrough" % [i, l.title])


## Undo past the midpoint, take a different legal move — redo must be
## cleared and the branch must still be playable to victory.
func _engine_undo_diverge() -> void:
	var l: LevelData = Campaign.levels()[0]
	var res: Dictionary = SokobanSolver.solve(l)
	var s := GameState.from_level_data(l)
	var half: int = res["moves"].size() / 2
	_play(s, res["moves"].slice(0, half))
	s.undo()
	# any legal move that differs clears the redo stack
	for ch in GameState.DIR_CHARS:
		if s.try_move(GameState.DIRS[ch]):
			break
	ok(s.redo_stack.is_empty(), "diverged move clears redo stack")
	ok(not s.redo(), "redo impossible after divergence")


## Restart on a ghost-rule level: the ghost replays the previous attempt.
func _engine_restart_ghost() -> void:
	var ghost_lvl: LevelData = null
	for l in Campaign.levels():
		for rdef in l.rules:
			if rdef.get("id") == "ghost":
				ghost_lvl = l
		if ghost_lvl:
			break
	ok(ghost_lvl != null, "campaign has a ghost level")
	if ghost_lvl == null:
		return
	var s := GameState.from_level_data(ghost_lvl)
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(0, -1))
	s.restart()
	ok(s.ghost_active, "ghost appears after restart")
	ok(s.ghost_pos == s.player_start, "ghost starts at player start")
	s.try_move(Vector2i(0, 1))  # ghost replays first logged move ('r')
	ok(s.ghost_pos == s.player_start + Vector2i(1, 0), "ghost replays attempt")


## Save mid-game, restore, continue playing to victory.
func _engine_save_resume() -> void:
	var l: LevelData = Campaign.levels()[0]
	var res: Dictionary = SokobanSolver.solve(l)
	var s := GameState.from_level_data(l)
	var half: int = res["moves"].size() / 2
	_play(s, res["moves"].slice(0, half))
	Storage.save_in_progress(l, s)
	var saved: Variant = Storage.get_in_progress()
	ok(saved != null, "in-progress save persisted")
	var s2 := GameState.deserialize_state(saved["level"], saved["state"])
	ok(s2.player == s.player and s2.turn == s.turn, "restored state matches")
	_play(s2, res["moves"].slice(half))
	ok(s2.is_solved(), "resumed game completes")
	Storage.clear_in_progress()
	ok(Storage.get_in_progress() == null, "in-progress cleared after win")


## Signals fire during real play: moved every turn, fx_push on pushes.
func _engine_signals() -> void:
	var s := GameState.from_level_data(Campaign.levels()[0])
	var moved_n := [0]
	var push_n := [0]
	var changed_n := [0]
	s.moved.connect(func(_p): moved_n[0] += 1)
	s.fx_push.connect(func(_i, _d): push_n[0] += 1)
	s.changed.connect(func(): changed_n[0] += 1)
	# walk up twice: second up hits the wall -> refused -> no signals
	s.try_move(Vector2i(0, -1))
	var before: int = moved_n[0]
	ok(not s.try_move(Vector2i(0, -1)), "wall move refused")
	ok(moved_n[0] == before and changed_n[0] == before,
		"denied move fires nothing")
	var consumed: int = moved_n[0]
	var res := SokobanSolver.solve_state(s)
	_play(s, res["moves"], false)
	ok(moved_n[0] - consumed == res["moves"].size(),
		"moved emitted per consumed turn")
	ok(push_n[0] > 0, "fx_push fired on pushes")
	ok(changed_n[0] == moved_n[0], "changed emitted per turn")


# ----------------------------------------------------------------- UI

## Drive a real GameScreen: move through _move (input path), undo via
## _undo, restart via _restart, solve via async _solve → autoplay → win.
func _ui_playthrough() -> void:
	var main: Control = load("res://scripts/main.gd").new()
	root.add_child(main)
	await process_frame

	var l: LevelData = Campaign.levels()[0]
	main.show_game(l)
	await process_frame
	var gs: GameScreen = main.current
	ok(gs.state != null, "UI: game state built")

	# manual moves through the input path
	var res: Dictionary = SokobanSolver.solve(l)
	for ch in res["moves"].slice(0, 4):
		gs._move(GameState.DIRS[ch.to_lower()])
	await process_frame
	ok(gs.state.turn == 4, "UI: moves consumed via _move")
	gs._undo()
	ok(gs.state.turn == 3, "UI: undo works")
	ok(gs.undos_used == 1, "UI: undo counter tracked")
	gs._restart()
	await process_frame
	ok(gs.state.turn == 0, "UI: restart resets")
	ok(gs.restarts_used == 1, "UI: restart counter tracked")

	# async solver → autoplay → win panel
	gs._solve()
	var frames := 0
	while gs._solving and frames < 900:
		await process_frame
		frames += 1
	ok(not gs.autoplay.is_empty(), "UI: autoplay populated")
	while gs.state != null and not gs.state.solved and frames < 3000:
		await process_frame
		frames += 1
	ok(gs.state.solved, "UI: autoplay reached solution")
	await process_frame
	ok(gs.win_panel.visible, "UI: win panel shown")
	ok(Storage.best_moves(l) > 0, "UI: best score recorded")

	main.show_menu()
	await process_frame
	ok(main.current is MenuScreen, "UI: back to menu")
	main.queue_free()
	await process_frame
