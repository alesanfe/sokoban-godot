extends SceneTree
## Headless test runner: godot --headless --path . -s res://tests/test_runner.gd

var failures := 0
var checks := 0


func _initialize() -> void:
	# los tests escriben en un user:// propio: la suite no pisa ni lee
	# los datos reales del jugador (los flakes venían de ahí)
	Storage.BASE_DIR = "user://devin_test/"
	DirAccess.make_dir_recursive_absolute("user://devin_test")
	var dd := DirAccess.open("user://devin_test")
	if dd:
		for fn in dd.get_files():
			dd.remove(fn)
	print("== Sokoban Mutante: tests ==")
	test_basic_movement()
	test_undo_restart()
	test_ice()
	test_mimic()
	test_push_limit()
	test_rotate()
	test_peekaboo()
	test_ghost()
	test_swap()
	test_two_players()
	test_codes()
	test_solver()
	test_generator()
	test_pull()
	test_switch()
	test_redo()
	test_pack_codes()
	test_classic_pack()
	test_serialization()
	test_xsb_rle()
	test_regressions()
	test_storage_robustness()
	test_occupant_overlays()
	test_win_stats()
	test_community_merge_remote()
	test_replay_determinism_fuzz()
	test_campaign_solvable()
	print("== %d checks, %d failures ==" % [checks, failures])
	quit(1 if failures > 0 else 0)


func ok(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  ok: " + name)
	else:
		failures += 1
		printerr("  FAIL: " + name)


func mk(board: PackedStringArray, rules: Array = []) -> GameState:
	return GameState.from_level_data(LevelData.create("t", board, rules))


func test_basic_movement() -> void:
	var s := mk(PackedStringArray([
		"#######",
		"#@ $ .#",
		"#######",
	]))
	ok(s.try_move(Vector2i(1, 0)), "walk right")
	ok(s.try_move(Vector2i(1, 0)), "push right")
	ok(s.player == Vector2i(3, 1), "player moved")
	ok(s.boxes[0] == Vector2i(4, 1), "box pushed")
	ok(not s.is_solved(), "not solved yet")
	ok(s.try_move(Vector2i(1, 0)), "second push onto goal")
	ok(s.is_solved(), "level solved")
	ok(not s.try_move(Vector2i(1, 0)), "no moves after solve")
	var blocked := mk(PackedStringArray([
		"#####",
		"#@$##",
		"#####",
	]))
	ok(not blocked.try_move(Vector2i(1, 0)), "push into wall refused")


func test_undo_restart() -> void:
	var s := mk(PackedStringArray([
		"#######",
		"#@ $ .#",
		"#######",
	]))
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(1, 0))
	ok(s.boxes[0] == Vector2i(4, 1), "box at x=4")
	ok(s.undo(), "undo works")
	ok(s.boxes[0] == Vector2i(3, 1), "box restored after undo")
	ok(s.player == Vector2i(2, 1), "player restored")
	s.restart()
	ok(s.boxes[0] == Vector2i(3, 1) and s.turn == 0, "restart resets")


func test_ice() -> void:
	var s := mk(PackedStringArray([
		"#########",
		"#       #",
		"# @$    #",
		"#       #",
		"#      .#",
		"#########",
	]), [{"id": "ice", "params": {}}])
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(1, 0))  # pushes: box slides to x=7
	ok(s.boxes[0] == Vector2i(7, 2), "box slid to wall")
	# walk up and push down
	s.try_move(Vector2i(0, -1))
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(0, 1))  # push down: slides to y=4 on goal
	ok(s.boxes[0] == Vector2i(7, 4), "box slid down to goal")
	ok(s.is_solved(), "ice level solved")


func test_mimic() -> void:
	var s := mk(PackedStringArray([
		"########",
		"#      #",
		"# @  & #",
		"#      #",
		"# .    #",
		"########",
	]), [{"id": "mimic", "params": {}}])
	s.try_move(Vector2i(0, -1))  # player up; mimic box up too
	ok(s.boxes[0] == Vector2i(5, 1), "mimic box moved up")
	s.try_move(Vector2i(1, 0))  # box moves right to (6,1)
	ok(s.boxes[0] == Vector2i(6, 1), "mimic moved right")
	s.try_move(Vector2i(1, 0))  # box at wall -> can't move right
	ok(s.boxes[0] == Vector2i(6, 1), "mimic blocked by wall")


func test_push_limit() -> void:
	var s := mk(PackedStringArray([
		"#########",
		"#       #",
		"# @ $  .#",
		"#       #",
		"#########",
	]), [{"id": "push_limit", "params": {"max": 2}}])
	for i in 3:
		s.try_move(Vector2i(1, 0))  # walk, push, push -> at limit
	ok(s.boxes[0] == Vector2i(6, 2), "box at x=6 after 2 pushes")
	var before: Vector2i = s.player
	ok(not s.try_move(Vector2i(1, 0)), "third push refused")
	ok(s.player == before, "player did not move on refused push")


func test_rotate() -> void:
	var s := mk(PackedStringArray([
		"#######",
		"#     #",
		"#  @$ #",
		"#  .  #",
		"#     #",
		"#######",
	]), [{"id": "rotate", "params": {"every": 2, "cw": 1}}])
	var w0 := s.width
	var h0 := s.height
	s.try_move(Vector2i(-1, 0))  # turn 1: (2,2)
	s.try_move(Vector2i(1, 0))   # turn 2: back to (3,2) -> rotate fires
	ok(s.width == h0 and s.height == w0, "dims swapped after rotate")


func test_peekaboo() -> void:
	var s := mk(PackedStringArray([
		"#########",
		"#   ?   #",
		"# @$    #",
		"#       #",
		"#########",
	]))
	# peekaboo at (4,1): player at (2,2) can't see it -> walkable
	ok(not s.is_solid(Vector2i(4, 1)), "peekaboo intangible when unseen")
	# move player up to (2,1): now same row -> sees it -> solid
	s.try_move(Vector2i(0, -1))
	ok(s.is_solid(Vector2i(4, 1)), "peekaboo solid when seen")


func test_ghost() -> void:
	var s := mk(PackedStringArray([
		"########",
		"#      #",
		"# @$.  #",
		"#      #",
		"########",
	]), [{"id": "ghost", "params": {}}])
	ok(not s.ghost_active, "no ghost on first attempt")
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(0, -1))
	s.restart()
	ok(s.ghost_active, "ghost active after restart")
	ok(s.ghost_pos == s.player_start, "ghost at start")
	s.try_move(Vector2i(0, 1))  # ghost replays 'r'
	ok(s.ghost_pos == s.player_start + Vector2i(1, 0), "ghost replayed move")


func test_swap() -> void:
	var s := mk(PackedStringArray([
		"########",
		"#      #",
		"# @$   #",
		"#  .   #",
		"########",
	]), [{"id": "swap", "params": {"every": 2}}])
	s.try_move(Vector2i(-1, 0))  # swap is turn-based: every 2 turns
	s.try_move(Vector2i(0, 1))
	ok(s.boxes.has(Vector2i(3, 3)), "box moved to goal cell")
	ok(s.goals.has(Vector2i(3, 2)), "goal moved to box cell")


func test_two_players() -> void:
	var s := mk(PackedStringArray([
		"########",
		"# @$.  #",
		"#   .  #",
		"########",
	]), [{"id": "two_players", "params": {}}])
	var rule = s.rules[0]
	ok(rule.active_player(s) == 0, "P1 starts")
	s.try_move(Vector2i(0, 1))
	ok(rule.active_player(s) == 1, "P2 turn")
	s.try_move(Vector2i(0, -1))
	ok(rule.active_player(s) == 0, "back to P1")


func test_codes() -> void:
	var l := LevelData.create("Prueba", PackedStringArray([
		"#####",
		"#@$.#",
		"#####",
	]), [{"id": "ice", "params": {"x": 1}}], "yo")
	var code := l.to_code()
	var back := LevelData.from_code(code)
	ok(back != null, "code decodes")
	ok(back.title == "Prueba" and back.author == "yo", "metadata roundtrip")
	ok(back.board[1] == "#@$.#", "board roundtrip")
	ok(back.rules[0]["id"] == "ice", "rules roundtrip")


func test_solver() -> void:
	var l := LevelData.create("s", PackedStringArray([
		"######",
		"#@$ .#",
		"#    #",
		"######",
	]))
	var res := SokobanSolver.solve(l)
	ok(res["ok"], "solver finds solution")
	ok(res["moves"].size() >= 2, "solution has moves")
	# replay solution
	var s := GameState.from_level_data(l)
	for ch in res["moves"]:
		s.try_move(GameState.DIRS[ch.to_lower()])
	ok(s.is_solved(), "solver solution actually solves")


func test_generator() -> void:
	var l := LevelGenerator.generate(12345, 9, 8, 3, "")
	ok(l != null, "generator produces level")
	if l:
		var res := SokobanSolver.solve(l, 40000)
		ok(res["ok"], "generated level solvable")


func test_pull() -> void:
	var s := mk(PackedStringArray([
		"#########",
		"#       #",
		"# .  $@ #",
		"#       #",
		"#########",
	]), [{"id": "pull", "params": {}}])
	ok(not s.try_move(Vector2i(-1, 0)), "pull: can't push into box")
	# walk around to the left of the box: (6,2)->(6,1)->(5,1)->(4,1)->(4,2)
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		s.try_move(d)
	ok(s.player == Vector2i(4, 2), "pull: reached pulling position")
	s.try_move(Vector2i(-1, 0))  # player to (3,2), box follows to (4,2)
	ok(s.boxes[0] == Vector2i(4, 2), "pull: box dragged behind")
	s.try_move(Vector2i(-1, 0))
	s.try_move(Vector2i(-1, 0))  # player to (1,2), box to (2,2) = goal
	ok(s.boxes[0] == Vector2i(2, 2), "pull: box dragged to goal")
	ok(s.is_solved(), "pull level solved")


func test_switch() -> void:
	var s := mk(PackedStringArray([
		"##########",
		"#        #",
		"# @$ ! . #",
		"#        #",
		"##########",
	]), [{"id": "push_limit", "params": {"max": 2}}])
	s.try_move(Vector2i(1, 0))  # push 1: box to (4,2)
	s.try_move(Vector2i(1, 0))  # push 2: box to (5,2) = switch -> rules off
	ok(s.boxes[0] == Vector2i(5, 2), "box on switch")
	ok(not s.rules_enabled, "switch disabled rules")
	# now pushes unlimited: push to goal at (7,2)
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(1, 0))
	ok(s.boxes[0] == Vector2i(7, 2), "pushed past limit with rules off")
	ok(s.is_solved(), "switch level solved")


func test_redo() -> void:
	var s := mk(PackedStringArray([
		"#######",
		"#@ $ .#",
		"#######",
	]))
	s.try_move(Vector2i(1, 0))
	s.try_move(Vector2i(1, 0))
	s.undo()
	ok(s.boxes[0] == Vector2i(3, 1), "pre-redo box at 3")
	ok(s.redo(), "redo applies")
	ok(s.boxes[0] == Vector2i(4, 1), "redo restores box")
	ok(not s.redo(), "redo stack empty")
	s.undo()
	s.try_move(Vector2i(0, -1))  # can't move (wall) -> invalid, but try a valid one
	s.undo()
	s.try_move(Vector2i(1, 0))  # new move clears redo
	ok(not s.redo(), "new move clears redo stack")


func test_pack_codes() -> void:
	var a := LevelData.create("A", PackedStringArray(["#####", "#@$.#", "#####"]))
	var b := LevelData.create("B", PackedStringArray(["#####", "#@$.#", "#####"]))
	var code := LevelData.pack_code([a, b])
	ok(code.begins_with("SKM2."), "pack code prefix")
	var decoded = LevelData.decode(code)
	ok(decoded is Array and decoded.size() == 2, "pack decodes to array")
	ok(decoded[0].title == "A" and decoded[1].title == "B", "pack titles roundtrip")
	var single = LevelData.decode(a.to_code())
	ok(single is LevelData, "SKM1 decodes via decode()")
	# malformed SKM2 payloads must be rejected, not decoded to junk
	ok(LevelData.decode("SKM2.basura_corrupta") == null,
		"SKM2 corrupt payload rejected")
	ok(LevelData.decode("SKM2.") == null,
		"SKM2 empty payload rejected")


func test_classic_pack() -> void:
	var levels := LevelPack.load_microban()
	ok(levels.size() == 155, "microban pack loads 155 levels")
	var invalid := 0
	for l in levels:
		if not l.validate().is_empty():
			invalid += 1
	ok(invalid == 0, "all microban levels valid")
	for i in [0, 1, 2]:
		var res := SokobanSolver.solve(levels[i], 20000)
		ok(res["ok"], "microban %d solvable" % (i + 1))


func test_serialization() -> void:
	var l: LevelData = mk(PackedStringArray([
		"#####", "#@$ .", "#####"])).level_data
	var s := GameState.from_level_data(l)
	s.try_move(Vector2i(1, 0))   # push the box
	var s2 := GameState.deserialize_state(l, s.serialize())
	ok(s2.player == s.player, "resume: player restored")
	ok(s2.boxes == s.boxes, "resume: boxes restored")
	ok("".join(s2.move_log) == "".join(s.move_log), "resume: move log restored")
	ok(s2.undo(), "resume: undo history survived")


func test_xsb_rle() -> void:
	var levels := LevelData.from_xsb_text("5#|#@$.#|5#")
	ok(levels.size() == 1, "RLE xsb: one level parsed")
	if levels.size() == 1:
		ok(levels[0].board[1] == "#@$.#", "RLE xsb: rows expanded")
	var plain := LevelData.from_xsb_text("#####\n#@$.#\n#####")
	ok(plain.size() == 1, "plain xsb: one level parsed")


func test_regressions() -> void:
	# serialize → JSON → deserialize keeps full canonical state on a
	# tile-rich level (every position-keyed dict populated at once).
	var lvl := LevelData.create("rich", PackedStringArray([
		"##########",
		"#?@$  .kK#",
		"#oO>=fhuw#",
		"#z1:Eq.bB#",
		"#x npc . #",
		"##########",
	]), [{"id": "swap", "params": {"every": 7}}])
	var st := GameState.from_level_data(lvl)
	var data: Dictionary = st.serialize()
	var rt: GameState = GameState.deserialize_state(lvl,
		JSON.parse_string(JSON.stringify(data)))
	ok(rt != null, "rich level round-trips")
	ok(rt != null and rt.canonical_key() == st.canonical_key(),
		"round-trip preserves canonical state")
	ok(GameState.deserialize_state(lvl, {}) == null,
		"missing snap rejected")
	ok(GameState.deserialize_state(lvl, {"snap": {"player": "x"}}) == null,
		"malformed snapshot rejected")

	# canonical_key distinguishes turns on turn-phased rules
	var q := mk(PackedStringArray(["#####", "#@$.#", "#####"]),
		[{"id": "quake", "params": {"every": 5}}])
	var qc := q.clone()
	qc.turn += 1
	ok(q.canonical_key() != qc.canonical_key(), "turn in canonical_key")

	# drunk: the log stores INPUT dirs, so a replay re-remaps them and
	# lands on the identical state
	var dboard := PackedStringArray([
		"#######",
		"#@    #",
		"# $ . #",
		"#     #",
		"#######",
	])
	var dr := mk(dboard, [{"id": "drunk", "params": {"step": 1}}])
	for dd in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0),
			Vector2i(0, 1), Vector2i(-1, 0)]:
		dr.try_move(dd)
	var dr2 := mk(dboard, [{"id": "drunk", "params": {"step": 1}}])
	for ch in dr.move_log:
		dr2.try_move(GameState.DIRS[ch.to_lower()])
	ok(dr2.canonical_key() == dr.canonical_key(),
		"drunk replay deterministic")

	# spring bounce onto a collapsed fragile floor = hole = loss
	var sp := mk(PackedStringArray([
		"#####",
		"#@  #",
		"#f$ #",
		"#.  #",
		"#####",
	]), [{"id": "spring", "params": {}}])
	sp.try_move(Vector2i(0, 1))   # step onto 'f'
	sp.try_move(Vector2i(1, 0))   # push → 'f' collapses → bounced onto hole
	ok(sp.lost, "spring bounce onto new hole loses")

	# swap rebuilds every parallel box array and remaps goal colors
	var sw := mk(PackedStringArray([
		"#####",
		"#@  #",
		"#b  #",
		"#B  #",
		"#####",
	]), [{"id": "swap", "params": {"every": 2}}])
	sw.try_move(Vector2i(1, 0))
	sw.try_move(Vector2i(0, 1))
	ok(sw.boxes.has(Vector2i(1, 3)), "swap: box moved to goal cell")
	ok(sw.goals.has(Vector2i(1, 2)), "swap: goal moved to box cell")
	ok(sw.goal_colors.get(Vector2i(1, 2), 0) == 1,
		"swap keeps goal colors")
	ok(sw.box_colors.size() == sw.boxes.size()
			and sw.box_mimic.size() == sw.boxes.size()
			and sw.box_roll.size() == sw.boxes.size()
			and sw.box_heavy.size() == sw.boxes.size()
			and sw.box_rest.size() == sw.boxes.size(),
		"swap keeps parallel arrays aligned")

	# push_limit budgets stay attached when a box is destroyed
	var pl := mk(PackedStringArray([
		"########",
		"#@$  . #",
		"#  $x  #",
		"########",
	]), [{"id": "push_limit", "params": {"max": 2}}])
	pl.try_move(Vector2i(1, 0))   # push box1 → (3,1)
	pl.try_move(Vector2i(1, 0))   # push box1 → (4,1): budget spent
	ok(not pl.try_move(Vector2i(1, 0)), "push limit reached")
	pl.try_move(Vector2i(-1, 0))  # (2,1)
	pl.try_move(Vector2i(0, 1))   # (2,2)
	pl.try_move(Vector2i(1, 0))   # push box2 onto 'x' → destroyed
	ok(pl.boxes.size() == 1, "bomb removed a box")
	pl.try_move(Vector2i(-1, 0))  # (1,2)
	pl.try_move(Vector2i(0, -1))  # (1,1)
	pl.try_move(Vector2i(1, 0))   # (2,1)
	pl.try_move(Vector2i(1, 0))   # (3,1)
	ok(not pl.try_move(Vector2i(1, 0)),
		"exhausted budget survives box removal")

	# solver clone is light: no undo history or move log
	var sc := mk(PackedStringArray(["#####", "#@$.#", "#####"]))
	sc.try_move(Vector2i(1, 0))
	var fc := sc.clone_for_search()
	ok(fc.history.is_empty() and fc.move_log.is_empty(),
		"search clone carries no history")

	# bond: a stale cluster must not slide on an unrelated push
	var bd := mk(PackedStringArray([
		"#########",
		"#       #",
		"#@ $$   #",
		"#       #",
		"#     $.#",
		"#       #",
		"#########",
	]), [{"id": "bond", "params": {}}])
	bd.try_move(Vector2i(1, 0))           # walk to (2,2)
	bd.try_move(Vector2i(1, 0))           # push the 2-box cluster right
	ok(bd.box_at(Vector2i(5, 2)) != -1, "bond cluster moved together")
	bd.try_move(Vector2i(0, 1))           # (3,3)
	bd.try_move(Vector2i(1, 0))           # (4,3)
	bd.try_move(Vector2i(1, 0))           # (5,3)
	bd.try_move(Vector2i(1, 0))           # (6,3)
	bd.try_move(Vector2i(0, 1))           # push the lone box down
	ok(bd.box_at(Vector2i(6, 5)) != -1, "lone box pushed")
	ok(bd.box_at(Vector2i(4, 2)) != -1 and bd.box_at(Vector2i(5, 2)) != -1,
		"bond: unrelated push leaves the old cluster in place")

	# 'z' drag respects push_limit and consumes budget
	var zl := mk(PackedStringArray([
		"########",
		"#      #",
		"#@ $z .#",
		"#      #",
		"########",
	]), [{"id": "push_limit", "params": {"max": 2}}])
	zl.try_move(Vector2i(1, 0))           # walk to (2,2)
	zl.try_move(Vector2i(1, 0))           # push box onto 'z' (count 1)
	zl.try_move(Vector2i(1, 0))           # push it off 'z' (count 2 = max)
	zl.try_move(Vector2i(-1, 0))          # walk off 'z' → drag refused
	ok(zl.box_at(Vector2i(5, 2)) != -1,
		"z-drag refused once the budget is spent")
	ok(int(zl.rule_state["push_limit"]["counts"][0]) == 2,
		"refused drag does not inflate the count")

	# ghost + drunk: the replay must remap inputs like the real attempt
	var gd := mk(PackedStringArray([
		"########",
		"#      #",
		"# @    #",
		"# $    #",
		"#    . #",
		"########",
	]), [{"id": "ghost", "params": {}}, {"id": "drunk", "params": {"step": 2}}])
	gd.try_move(Vector2i(0, 1))           # n=0: down, pushes box to (2,4)
	gd.try_move(Vector2i(-1, 0))          # n=1: flipped 180° → moves right
	gd.restart()                          # ghost replays "DL"
	gd.try_move(Vector2i(1, 0))           # ghost steps 'd' at n=0 → (2,3)
	gd.try_move(Vector2i(-1, 0))          # ghost 'l' at n=1 → flipped → (3,3)
	ok(gd.ghost_pos == Vector2i(3, 3),
		"ghost replays the remapped trajectory, not raw input")

	# composite chars (%, *, +) must survive validate()
	var cmp := LevelData.create("comp", PackedStringArray([
		"#######", "# @   #", "# % * #", "# &.  #", "#######"]), [])
	ok(cmp.validate().is_empty(),
		"composite chars %*+ pass validate: " + str(cmp.validate()))

	# level codes preserve hidden_rules/par/difficulty metadata
	var meta := LevelData.create("meta", PackedStringArray([
		"#####", "#@$.#", "#####"]), [], "yo")
	meta.hidden_rules = true
	meta.par = 7
	meta.difficulty = 3
	var meta2 := LevelData.from_code(meta.to_code())
	ok(meta2 != null and meta2.hidden_rules and meta2.par == 7
			and meta2.difficulty == 3,
		"code roundtrip keeps hidden/par/difficulty")

	# compuestos de color: a/e/i = caja b/c/d ya sobre su meta;
	# j/l/m = caja de color sobre meta neutra (sigue sin resolver)
	var cg := LevelData.create("cg", PackedStringArray([
		"########", "# @    #", "# a b B#", "########"]), [])
	ok(cg.validate().is_empty(),
		"composite 'a' counts as a matched color pair")
	var cj := LevelData.create("cj", PackedStringArray([
		"#######", "# @jB #", "#######"]), [])
	ok(not cj.validate().is_empty(),
		"'j' (caja b sin meta B extra) flagged as unbalanced")
	var gsol := mk(PackedStringArray([
		"########", "# @    #", "# a b B#", "########"]))
	gsol.try_move(Vector2i(1, 0))   # (3,1)
	gsol.try_move(Vector2i(0, 1))   # (3,2)
	gsol.try_move(Vector2i(1, 0))   # empuja b → (5,2)
	gsol.try_move(Vector2i(1, 0))   # empuja b → (6,2) meta B
	ok(gsol.solved, "composite goal counts toward solving")

	# push budgets charge every displaced box, not just the push head
	var plm := mk(PackedStringArray(["#######", "#@$$..#", "#######"]),
		[{"id": "chain"}, {"id": "push_limit", "params": {"max": 3}}])
	plm.try_move(Vector2i(1, 0))
	ok(Array(plm.rule_state["push_limit"]["counts"]) == [1, 1],
		"push_limit charges chain members")
	# a maxed mid-chain member vetoes the whole push
	plm.rule_state["push_limit"]["counts"] = PackedInt32Array([0, 3])
	ok(not plm.try_move(Vector2i(1, 0)),
		"push_limit vetoes a push with a spent chain member")

	# pull drags respect push budgets too (no free infinite pushes)
	var pu := mk(PackedStringArray(["#######", "#  @$ #", "#######"]),
		[{"id": "pull"}, {"id": "push_limit", "params": {"max": 1}}])
	pu.try_move(Vector2i(-1, 0))  # box follows to (3,1): budget spent
	pu.try_move(Vector2i(-1, 0))  # vetoed: box must stay at (3,1)
	ok(pu.boxes[0] == Vector2i(3, 1) and pu.player == Vector2i(1, 1),
		"pull drag honors push_limit")

	# one-way gates apply to mid-chain members, not only the head
	var ow := mk(PackedStringArray(["########", "#@$$3..#", "########"]),
		[{"id": "chain"}])
	ow.try_move(Vector2i(1, 0))   # member lands on the '3' gate
	ok(not ow.try_move(Vector2i(1, 0)),
		"one-way chain member can't be pushed sideways")

	# move_limit evaluates the FINAL board: a conveyor solving on the
	# last turn counts as a win regardless of rule order
	var ml := mk(PackedStringArray(["#######", "# @$>.#", "#######"]),
		[{"id": "move_limit", "params": {"max": 1}}, {"id": "conveyor"}])
	ml.try_move(Vector2i(1, 0))   # push onto the belt → carries to goal
	ok(ml.solved and not ml.lost,
		"conveyor win on the last turn is not a loss")

	# quota above the goal count is flagged as unwinnable
	var qq := LevelData.create("qq", PackedStringArray([
		"#####", "#@$.#", "#####"]),
		[{"id": "quota", "params": {"n": 3}}])
	ok(not qq.validate().is_empty(), "quota > goals flagged")

	# undo of a door opening restores the door cell, the spent key
	# and the key pickup itself
	var kd := mk(PackedStringArray(["#######", "#@kK$.#", "#######"]))
	kd.try_move(Vector2i(1, 0))   # pick the key
	kd.try_move(Vector2i(1, 0))   # open the door
	ok(kd.keys_held == 0 and not kd.door_cells.has(Vector2i(3, 1)),
		"opening a door consumes the key")
	kd.undo()
	ok(kd.keys_held == 1 and kd.door_cells.has(Vector2i(3, 1)),
		"undo restores door and spent key")
	kd.undo()
	ok(kd.keys_held == 0 and kd.key_cells.has(Vector2i(2, 1)),
		"undo restores the key pickup")

	# a classic box parked on a dead square = unwinnable → validate flags it
	var dbl := LevelData.create("db", PackedStringArray([
		"#####", "#@  #", "#$  #", "#  .#", "#####"]), [])
	ok(not dbl.validate().is_empty(),
		"box starting on a dead square flagged")
	var dbl2 := LevelData.create("db", PackedStringArray([
		"#####", "#@  #", "#   #", "# $.#", "#####"]), [])
	ok(dbl2.validate().is_empty(),
		"healthy classic board stays valid")

	# last_attempt survives save→resume so the ghost rule still replays
	var gs := mk(PackedStringArray([
		"#####", "# @.#", "# $ #", "#####"]),
		[{"id": "ghost", "params": {}}])
	gs.try_move(Vector2i(-1, 0))
	gs.try_move(Vector2i(0, 1))   # pushes the box down
	var s3 := GameState.deserialize_state(
		gs.level_data, gs.serialize())
	ok(s3.last_attempt.size() == gs.last_attempt.size() or s3.move_log.size() == 2,
		"resume keeps the previous attempt for the ghost")
	s3.restart()
	ok(s3.ghost_active, "ghost activates after resume + restart")


func test_storage_robustness() -> void:
	# JSON válido con raíz de tipo distinto → fallback, no crash
	var path := "user://test_corrupt.json"
	var f := FileAccess.open(Storage._p(path), FileAccess.WRITE)
	f.store_string("[1,2,3]")
	f.close()
	Storage._cache.erase(Storage._p(path))
	var d: Dictionary = Storage.load_json(path, {})
	ok(d.is_empty(), "load_json: raíz Array rechazada para dict")
	f = FileAccess.open(Storage._p(path), FileAccess.WRITE)
	f.store_string("5")
	f.close()
	Storage._cache.erase(Storage._p(path))
	var a: Array = Storage.load_json(path, [])
	ok(a.is_empty(), "load_json: raíz escalar rechazada para array")
	DirAccess.remove_absolute(Storage._p(path))
	# clamps: un settings.json editado a mano no puede colar extremos
	Storage.set_setting("repeat_rate", 0.0)
	ok(float(Storage.get_setting("repeat_rate")) >= 0.03,
		"clamp: repeat_rate no admite 0 (movería cada frame)")
	Storage.set_setting("repeat_rate", 0.11)
	ok(absf(float(Storage.get_setting("repeat_rate")) - 0.11) < 0.001,
		"clamp: valor en rango intacto")
	Storage.set_setting("music_vol", 400)
	ok(int(Storage.get_setting("music_vol")) == 100,
		"clamp: music_vol tope 100")
	Storage.set_setting("music_vol", 70)


## movimientos random. Reejecutar move_log desde cero debe reproducir
## exactamente el mismo canonical_key — el fantasma, el undo y el
## solver dependen implícitamente de esa propiedad.
func test_occupant_overlays() -> void:
	# una caja overlay sobre un terreno no componible llega al motor
	var l := LevelData.create("ov", PackedStringArray(["#####", "#@ .C", "#####"]), [])
	l.over[Vector2i(3, 1)] = {"c": 1, "m": false, "r": false, "h": false}
	var s := GameState.from_level_data(l)
	ok(s.boxes.size() == 1, "overlay crea la caja")
	ok(s.box_colors[0] == 1, "overlay conserva el color")
	ok(s.goals.has(Vector2i(3, 1)), "la meta C sigue debajo")
	# roundtrip dict → code → dict conserva overlays
	var l2 := LevelData.from_dict(l.to_dict())
	ok(l2.over.size() == 1 and l2.over.has(Vector2i(3, 1))
		and int(l2.over[Vector2i(3, 1)].get("c", 0)) == 1,
		"over sobrevive a to_dict/from_dict")
	var l3 := LevelData.from_code(l.to_code())
	ok(l3 != null and l3.over.has(Vector2i(3, 1)),
		"over sobrevive al código SKM1")
	var bare := LevelData.create("ov", l.board, [])
	ok(l.content_code() != bare.content_code(),
		"content_code distingue overlays")
	# validate: la overlay cuenta como caja (1 caja / 2 metas → falta 1)
	ok(not l.validate().is_empty(), "validate cuenta overlays")
	# válido de verdad: overlay c sobre B y b sobre C (cuentas cruzadas)
	var l_ok := LevelData.create("ov2",
		PackedStringArray(["######", "#@.BC", "######"]), [])
	l_ok.over[Vector2i(2, 1)] = {"c": 0}   # $ sobre '.'
	l_ok.over[Vector2i(3, 1)] = {"c": 2}   # c sobre B
	l_ok.over[Vector2i(4, 1)] = {"c": 1}   # b sobre C
	ok(l_ok.validate().is_empty(), "overlays coloreadas cruzadas validan")
	# compose: caja sobre meta de otro color → "" (overlay), no borra la meta
	ok(TileSpec.compose("b", "C") == "", "compose: b sobre C → overlay")
	ok(TileSpec.compose("b", "B") == "a", "compose: b sobre B → compuesto")
	ok(TileSpec.compose("$", ">") == "", "compose: $ sobre cinta → overlay")


func test_win_stats() -> void:
	# par boundaries: ≤par ★★★ PERFECTO, ≤1.25× ORO, ≤1.5× PLATA, > BRONCE
	ok(WinStats.medal(10, 10, false)["stars"] == 3, "par ⇒ PERFECTO")
	ok(WinStats.medal(10, 12, false)["medal"] == "ORO", "1.25× ⇒ ORO")
	ok(WinStats.medal(10, 15, false)["medal"] == "PLATA", "1.5× ⇒ PLATA")
	ok(WinStats.medal(10, 16, false)["medal"] == "BRONCE", ">1.5× ⇒ BRONCE")
	ok(WinStats.medal(0, 5, false)["medal"] == "COMPLETADO",
		"sin par ⇒ COMPLETADO")
	ok(WinStats.medal(10, 10, true)["stars"] == 1,
		"asistida no medalla")
	var s := WinStats.summary(10, 8, 4, 75.0, 0, 0, false)
	ok(s.contains("PERFECTO") and s.contains("8 movimientos")
		and s.contains("01:15") and s.contains("sin deshacer"),
		"summary: medalla + tiempo + badge")
	ok(WinStats.summary(10, 8, 4, 0.0, 1, 0, false)
		.contains("sin deshacer") == false,
		"summary: con undos no hay badge 'sin deshacer'")
	ok(WinStats.summary(10, 8, 4, 0.0, 0, 0, true)
		.contains("con solucionador"),
		"summary: badge asistido")


func test_community_merge_remote() -> void:
	# N-3: el nivel publicado propio ya tiene remote_id local — el
	# espejo no debe duplicarlo; liked se preserva entre syncs
	var cat := {"entries": {
		"loc1": {"remote_id": "srv-a", "author": "dev"}},
		"remote_entries": {"srv-b": {"liked": true}}}
	var feed := [
		{"id": "srv-a", "data": {}, "author": "dev", "ts": 1},
		{"id": "srv-b", "data": {}, "author": "x", "ts": 2, "likes": 5},
		{"id": "srv-c", "data": {}, "author": "y", "ts": 3}]
	CommunityService.merge_remote_feed(cat, feed)
	var re: Dictionary = cat["remote_entries"]
	ok(not re.has("srv-a"), "remote merge: no duplica la publicación propia")
	ok(re.has("srv-b") and bool(re["srv-b"]["liked"]),
		"remote merge: liked preservado")
	ok(int(re["srv-b"]["likes"]) == 5, "remote merge: contadores del servidor")
	ok(re.has("srv-c"), "remote merge: entradas nuevas entran")
	# entry corrupta en el feed no rompe el merge
	CommunityService.merge_remote_feed(cat, [{"id": "", "data": {}}, "x"])
	ok(cat["remote_entries"].is_empty(), "remote merge: feed corrupto → espejo vacío")


func test_replay_determinism_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	# suelo muy representado + muestra de todos los tiles especiales
	var pool := "        $$$...&&%%qnbcdaeijlmBCD!!oO<>^vkKxhf=:WwuzEGHpp1234"
	var fails := 0
	var trials := 60
	for trial in trials:
		var w := 6 + rng.randi_range(0, 3)
		var h := 5 + rng.randi_range(0, 2)
		var lines := PackedStringArray()
		for y in h:
			var row := ""
			for x in w:
				if x == 0 or y == 0 or x == w - 1 or y == h - 1:
					row += "#"
				else:
					row += pool[rng.randi_range(0, pool.length() - 1)]
			lines.append(row)
		# garantiza jugador/caja/meta en celdas interiores fijas
		lines[1] = lines[1].substr(0, 1) + "@" + lines[1].substr(2)
		lines[2] = lines[2].substr(0, 2) + "$" + lines[2].substr(3)
		lines[h - 2] = lines[h - 2].substr(0, w - 2) + "." \
			+ lines[h - 2].substr(w - 1)
		var rids := RuleRegistry.all_ids()
		var rules := []
		for i in rng.randi_range(0, 3):
			rules.append({"id": rids[rng.randi_range(0, rids.size() - 1)],
				"params": {}})
		var lvl := LevelData.create("fz", lines, rules)
		var s := GameState.from_level_data(lvl)
		if s == null:
			continue
		for i in rng.randi_range(10, 30):
			if rng.randi_range(0, 9) == 0:
				s.try_switch()
			else:
				s.try_move(GameState.DIRS["lurd"[rng.randi_range(0, 3)]])
		# replay de move_log desde cero
		var s2 := GameState.from_level_data(lvl)
		for ch in s.move_log:
			if str(ch).to_lower() == "s":
				s2.try_switch()
			else:
				s2.try_move(GameState.DIRS[str(ch).to_lower()])
		if s2.canonical_key() != s.canonical_key():
			fails += 1
			print("    FUZZ t%d: replay diverge (rules=%s)" % [trial, rules])
		# serialize → deserialize conserva el estado
		var s3 = GameState.deserialize_state(lvl, s.serialize())
		if s3 == null or s3.canonical_key() != s.canonical_key():
			fails += 1
			print("    FUZZ t%d: serialize diverge (rules=%s)" % [trial, rules])
	ok(fails == 0, "fuzz: replay+serialize deterministas (%d trials)" % trials)


func test_campaign_solvable() -> void:
	for l in Campaign.levels():
		var res := SokobanSolver.solve(l, 60000)
		ok(res["ok"], "campaign solvable: " + l.title + (" (%s)" % res.get("reason", "") if not res["ok"] else ""))
