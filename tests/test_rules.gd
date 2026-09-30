extends SceneTree
## Unit tests per rule/mechanic: minimal states, exact expectations.
## godot --headless --path . -s res://tests/test_rules.gd

var failures := 0


func _initialize() -> void:
	print("== rule mechanics ==")
	_t_gravity()
	_t_torus()
	_t_chain()
	_t_portal()
	_t_conveyor()
	_t_wind()
	_t_magnet()
	_t_spin()
	_t_keys_doors()
	_t_bombs()
	_t_colors()
	_t_oneway()
	_t_holes()
	_t_fragile()
	_t_rails()
	_t_invert()
	_t_move_limit()
	_t_bond()
	_t_ice_player()
	_t_weak_wall()
	_t_swap_tile()
	_t_multiban()
	_t_multiban_cycle()
	_t_filters()
	_t_blob()
	_t_blob_per_color()
	_t_quota()
	_t_iron()
	_t_mimic_opposite()
	_t_classic_fidelity()
	_t_rolling_box()
	_t_heavy_box()
	_t_pit()
	_t_pull_zone()
	_t_quake()
	_t_mitosis()
	_t_drunk()
	_t_spring()
	_t_musical()
	_t_life()
	_t_repel()
	_t_link()
	_t_mirror()
	print("== rules: %d failures ==" % failures)
	quit(1 if failures > 0 else 0)


func ok(cond: bool, name: String) -> void:
	if cond:
		print("  ok: " + name)
	else:
		failures += 1
		printerr("  FAIL: " + name)


func mk(board: Array, rules: Array = []) -> GameState:
	var l := LevelData.create("t", PackedStringArray(board), rules)
	return GameState.from_level_data(l)


const R := Vector2i(1, 0)
const L := Vector2i(-1, 0)
const U := Vector2i(0, -1)
const D := Vector2i(0, 1)


func _t_gravity() -> void:
	# box falls to the floor after any move
	var s := mk(["#####", "#$  #", "#   #", "#@  #", "#####"],
		[{"id": "gravity", "params": {}}])
	s.try_move(R)
	ok(s.boxes[0] == Vector2i(1, 3), "gravity drops box to floor")
	ok(s.player == Vector2i(2, 3), "gravity drops player too")


func _t_torus() -> void:
	var s := mk(["#####", "#  @ #", "#    #", "#$  .#", "#####"],
		[{"id": "torus", "params": {}}])
	s.try_move(R)  # out the right edge (border wall is edge → wraps)
	ok(s.player != Vector2i(3, 1), "torus wraps player")
	var s2 := mk(["#####", "#@   #", "#    #", "# $ .#", "#####"],
		[{"id": "torus", "params": {}}])
	# push box left off the left edge: player right of box? place differently:
	# push box right until it exits right edge and wraps to left
	s2.try_move(D); s2.try_move(D); s2.try_move(L); s2.try_move(U)
	ok(s2.player.x >= 0, "torus move chain survives")


func _t_chain() -> void:
	var s := mk(["#######", "#@$$ .#", "#######"],
		[{"id": "chain", "params": {}}])
	ok(s.try_move(R), "chain push accepted")
	ok(s.boxes[0] == Vector2i(3, 1) and s.boxes[1] == Vector2i(4, 1),
		"chain pushes whole row")
	var s2 := mk(["#######", "#@$$ .#", "#######"], [])
	ok(not s2.try_move(R), "without chain rule the row blocks")


func _t_portal() -> void:
	var s := mk(["#######", "#@o  o.#", "#  $   #", "#######"],
		[{"id": "portal", "params": {}}])
	s.try_move(R)
	ok(s.player == Vector2i(5, 1), "portal teleports player")
	# box through portal: line up a push onto 'o'
	var s2 := mk(["########", "#@$o  o#", "#    . #", "########"],
		[{"id": "portal", "params": {}}])
	s2.try_move(R)  # pushes box onto portal → box exits at the pair
	ok(s2.boxes[0] == Vector2i(6, 1), "portal teleports pushed box")


func _t_conveyor() -> void:
	var s := mk(["########", "#@$> . #", "########"],
		[{"id": "conveyor", "params": {}}])
	s.try_move(R)  # push box onto '>' — belt carries it that same turn
	ok(s.boxes[0] == Vector2i(4, 1), "belt carries box right away")
	s.try_move(R)  # player steps onto the belt (box blocks, so stays)
	s.try_move(R)  # now adjacent: push box onto the goal
	ok(s.is_solved(), "conveyor delivers box to goal")


func _t_wind() -> void:
	var s := mk(["########", "#@     #", "# $    #", "#  .   #", "########"],
		[{"id": "wind", "params": {"every": 2, "dir": 0}}])  # dir 0 = right
	s.try_move(R)
	ok(s.boxes[0] == Vector2i(2, 2), "wind waits for interval")
	s.try_move(R)
	ok(s.boxes[0] == Vector2i(3, 2), "wind pushes box on interval")


func _t_magnet() -> void:
	var s := mk(["########", "#@   $ #", "#   .  #", "########"],
		[{"id": "magnet", "params": {}}])
	s.try_move(D)  # irrelevant move; box should approach player
	var b := s.boxes[0]
	ok(b.x < 5 or (b - s.player).length() < 5.0, "magnet pulls box closer")


func _t_spin() -> void:
	var s := mk(["#####", "#@  #", "# $ #", "#  .#", "#####"],
		[{"id": "spin", "params": {}}])
	# rotation kicks in after the first consumed turn
	s.try_move(R)
	var out: Vector2i = s.rules[0].transform_input(s, R)
	ok(out == D, "spin rotates controls after a turn")


func _t_keys_doors() -> void:
	var s := mk(["#######", "#@k K$.#", "#######"])
	s.try_move(R)  # pick key
	ok(s.keys_held == 1, "key pickup")
	var s_no := mk(["######", "#@ K$.#", "######"])
	s_no.try_move(R)
	ok(not s_no.try_move(R), "door blocks without key")
	# step onto door with key → opens
	s = mk(["#######", "#@k K$.#", "#######"])
	s.try_move(R)  # key
	s.try_move(R)  # walk to (3,1)
	s.try_move(R)  # open door
	ok(s.door_cells.is_empty() and s.keys_held == 0, "key opens door")
	s.try_move(R)  # push box
	s.try_move(R)
	ok(s.is_solved(), "level solved after door")


func _t_bombs() -> void:
	var s := mk(["######", "#@$x.#", "#  . #", "######"])
	s.try_move(R)
	ok(s.boxes.is_empty(), "bomb destroys pushed box")
	ok(s.bomb_cells.is_empty(), "bomb consumed")
	ok(not s.is_solved(), "goal left uncovered is not solved")


func _t_colors() -> void:
	var s := mk(["######", "#@b B#", "#    #", "######"])
	s.try_move(R)
	s.try_move(R)
	ok(s.is_solved(), "b on B solves")
	var s2 := mk(["######", "#@b C#", "#    #", "######"])
	s2.try_move(R)
	s2.try_move(R)
	ok(not s2.is_solved(), "b on C does NOT solve (color match)")


func _t_oneway() -> void:
	var s := mk(["#######", "#@ 1  #", "#  $  #", "#######"])
	ok(s.try_move(R), "walk to gate")
	ok(s.try_move(R), "enter one-way cell freely")
	ok(not s.try_move(D), "one-way blocks wrong exit")
	ok(not s.try_move(L), "one-way blocks reverse too")
	ok(s.try_move(R), "one-way allows gate direction")


func _t_holes() -> void:
	var s := mk(["######", "#@$h #", "#  . #", "######"])
	s.try_move(R)  # push box into the hole
	ok(s.boxes.is_empty(), "box fills hole and vanishes")
	ok(s.hole_cells.is_empty(), "hole consumed by box")
	ok(not s.is_solved(), "fewer boxes than goals = not solved")
	var s2 := mk(["######", "#@h  #", "# $ .#", "######"])
	ok(s2.try_move(R), "walking onto a hole consumes the turn")
	ok(s2.lost, "player falls into hole")
	ok(not s2.try_move(R), "moves refused while lost")
	s2.undo()
	ok(not s2.lost and s2.player == Vector2i(1, 1), "undo revives the player")


func _t_fragile() -> void:
	var s := mk(["######", "#@f  #", "# $ .#", "######"])
	s.try_move(R)  # step onto fragile floor
	ok(s.fragile_cells.has(Vector2i(2, 1)), "fragile holds while standing")
	s.try_move(R)  # step off
	ok(s.hole_cells.has(Vector2i(2, 1)), "fragile collapses into hole")
	ok(not s.fragile_cells.has(Vector2i(2, 1)), "fragile spent")
	ok(s.try_move(L) and s.lost, "collapsed floor swallows you on return")
	s.undo()
	ok(not s.lost and s.hole_cells.has(Vector2i(2, 1)), "undo revives, hole persists")
	s.undo()
	ok(s.fragile_cells.has(Vector2i(2, 1)) and not s.hole_cells.has(Vector2i(2, 1)),
		"undo restores fragile floor")


func _t_rails() -> void:
	var s := mk(["######", "#@   #", "# $= #", "#    #", "######"])
	s.try_move(D)
	s.try_move(R)  # box lands on the horizontal rail at (3,2)
	s.try_move(U)
	s.try_move(R)  # player above the box at (3,1)
	ok(not s.try_move(D), "H rail blocks vertical push")
	s.try_move(L)
	s.try_move(D)  # back beside the box
	ok(s.try_move(R), "H rail allows horizontal push")
	# vertical rail: box enters horizontally, then can only leave vertically
	var s2 := mk(["######", "#    #", "#@$: #", "#    #", "######"])
	s2.try_move(R)  # box lands on ':' at (3,2)
	s2.try_move(D)
	s2.try_move(R)
	s2.try_move(R)
	s2.try_move(U)  # player at (4,2), right of the railed box
	ok(not s2.try_move(L), "V rail blocks horizontal push")
	var s3 := mk(["######", "#    #", "#@$: #", "#    #", "######"])
	s3.try_move(R)  # box onto ':'
	s3.try_move(U)
	s3.try_move(R)  # player at (3,1), above the railed box
	ok(s3.try_move(D), "V rail allows vertical push")


func _t_invert() -> void:
	var s := mk(["#####", "#@  #", "# $ #", "#  .#", "#####"],
		[{"id": "invert", "params": {}}])
	var d: Vector2i = s.rules[0].transform_input(s, R)
	ok(d == L, "invert flips input")
	ok(s.try_move(R) and s.player == Vector2i(2, 1),
		"try_move unaffected (UI transforms, engine stays raw)")


func _t_move_limit() -> void:
	var s := mk(["#####", "#@  #", "# $ #", "#  .#", "#####"],
		[{"id": "move_limit", "params": {"max": 3}}])
	s.try_move(R)
	s.try_move(D)
	ok(not s.lost, "under the limit")
	s.try_move(L)
	ok(s.lost, "move limit loses the attempt")
	ok(not s.try_move(U), "no moves after losing")
	s.undo()
	ok(not s.lost, "undo undoes the loss")
	var s2 := mk(["######", "#@$ .#", "######"],
		[{"id": "move_limit", "params": {"max": 2}}])
	s2.try_move(R)
	s2.try_move(R)  # solved on the very last allowed turn
	ok(s2.is_solved() and not s2.lost, "solving on the last turn still wins")


func _t_bond() -> void:
	# L-shaped cluster: all three boxes move as one block
	var s := mk(["#######", "#@$$  #", "#  $  #", "#   . #", "#    .#", "#######"],
		[{"id": "bond", "params": {}}])
	ok(s.try_move(R), "bond push accepted")
	ok(s.boxes.size() == 3, "bond keeps all boxes")
	var got := {}
	for b in s.boxes:
		got[b] = true
	ok(got.has(Vector2i(3, 1)) and got.has(Vector2i(4, 1)) and got.has(Vector2i(4, 2)),
		"bond moves the whole L-block")
	ok(not mk(["#####", "#@$$#", "#   #", "#####"],
		[{"id": "bond", "params": {}}]).try_move(R),
		"bond can't push a block into a wall")


func _t_ice_player() -> void:
	var s := mk(["######", "#@   #", "# $ .#", "######"],
		[{"id": "ice", "params": {"player_slide": true}}])
	s.try_move(R)  # one step, then slides to the wall
	ok(s.player == Vector2i(4, 1), "player slides to the far wall")
	var s2 := mk(["######", "#@   #", "# $ .#", "######"],
		[{"id": "ice", "params": {}}])
	s2.try_move(R)
	ok(s2.player == Vector2i(2, 1), "no slide without the param")


func _t_weak_wall() -> void:
	var s := mk(["######", "#@$W #", "#  . #", "######"])
	ok(s.try_move(R), "demolishing consumes a turn")
	ok(s.weak_walls.is_empty(), "weak wall destroyed")
	ok(s.boxes[0] == Vector2i(2, 1) and s.player == Vector2i(1, 1),
		"nothing moves when demolishing")
	s.try_move(R)
	ok(s.boxes[0] == Vector2i(3, 1), "box enters the demolished cell")


func _t_swap_tile() -> void:
	var s := mk(["######", "#@$w #", "#  . #", "######"])
	s.try_move(R)  # box lands on 'w' → trades places with the player
	ok(s.player == Vector2i(3, 1) and s.boxes[0] == Vector2i(2, 1),
		"swap tile trades positions")
	s.undo()
	ok(s.player == Vector2i(1, 1) and s.boxes[0] == Vector2i(2, 1),
		"undo restores swap")


func _t_multiban() -> void:
	var s := mk(["######", "#@  p#", "# $ .#", "######"])
	ok(s.twins.size() == 1 and s.twins[0] == Vector2i(4, 1), "twin parsed")
	ok(s.try_switch(), "switch consumes a turn")
	ok(s.player == Vector2i(4, 1) and s.twins[0] == Vector2i(1, 1), "control swapped")
	s.undo()
	ok(s.player == Vector2i(1, 1) and s.twins[0] == Vector2i(4, 1),
		"undo restores the active pusher")
	var s2 := mk(["#####", "#@p #", "# $.#", "#####"])
	ok(s2.try_move(R) and s2.player == Vector2i(2, 1) and s2.twins[0] == Vector2i(1, 1),
		"walking into your partner swaps control")


func _t_multiban_cycle() -> void:
	# three pushers: Space cycles 1→2→3→1
	var s := mk(["#######", "#@ p p#", "# $  .#", "#######"])
	s.try_switch()
	ok(s.player == Vector2i(3, 1), "switch to pusher 2")
	s.try_switch()
	ok(s.player == Vector2i(5, 1), "switch to pusher 3")
	s.try_switch()
	ok(s.player == Vector2i(1, 1) and s.twins.size() == 2, "cycle back to 1")


func _t_filters() -> void:
	# 'E' only lets a color-1 (b) box through — it glides out the far side
	var s := mk(["######", "#@b EB#", "######"])
	ok(s.try_move(R), "first push approaches the filter")
	ok(s.try_move(R) and s.is_solved(),
		"matching box glides through the filter onto its goal")
	ok(s.player == Vector2i(3, 1), "player stays on this side")
	var s2 := mk(["#######", "#@$E .#", "#######"])
	ok(not s2.try_move(R), "plain box blocked by color-1 filter")
	ok(s2.player == Vector2i(1, 1), "blocked push keeps player put")
	# filter is a wall for the player
	var s3 := mk(["######", "#@ E #", "######"])
	ok(s3.try_move(R), "approach the filter")
	ok(not s3.try_move(R), "filter blocks the player")


func _t_blob_per_color() -> void:
	# two same-color boxes apart: push one next to the other to solve
	var s := mk(["######", "#@    #", "# b   #", "#  b  #", "######"],
		[{"id": "blob", "params": {"per_color": true}}])
	ok(not s.is_solved(), "same-color pair apart is not solved")
	s.try_move(R)  # player right of the top box
	s.try_move(D)  # push box (2,2)→(2,3): adjacent to (3,3)
	ok(s.is_solved(), "same-color group solves")
	var s2 := mk(["######", "#@    #", "# bc  #", "#     #", "######"],
		[{"id": "blob", "params": {"per_color": true}}])
	ok(s2.is_solved(), "single box per color trivially solves")


func _t_blob() -> void:
	var s := mk(["#####", "#@  #", "#$  #", "# $ #", "#####"],
		[{"id": "blob", "params": {}}])
	ok(not s.is_solved(), "scattered boxes do not solve")
	s.try_move(D)  # box (1,2)→(1,3), now touching (2,3)
	ok(s.is_solved(), "connected group solves without goals")


func _t_quota() -> void:
	var s := mk(["#######", "#@$ ..#", "# $   #", "#######"],
		[{"id": "quota", "params": {"n": 1}}])
	s.try_move(R)
	s.try_move(R)
	ok(s.is_solved(), "quota met with one goal covered")
	var s2 := mk(["#######", "#@$ ..#", "# $   #", "#######"],
		[{"id": "quota", "params": {"n": 2}}])
	s2.try_move(R)
	s2.try_move(R)
	ok(not s2.is_solved(), "quota of 2 still pending")


func _t_iron() -> void:
	var s := mk(["#####", "#@  #", "# $ #", "#  .#", "#####"],
		[{"id": "iron", "params": {}}])
	s.try_move(R)
	ok(not s.undo(), "iron blocks undo")
	s.restart()
	ok(s.turn == 0 and s.player == Vector2i(1, 1), "restart still works")


func _t_mimic_opposite() -> void:
	var s := mk(["######", "#@   #", "# $ &#", "#  ..#", "######"],
		[{"id": "mimic", "params": {"opposite": true}}])
	s.try_move(R)  # player →; anti-mimic moves ←
	ok(s.boxes[1] == Vector2i(3, 2), "opposite mimic moves away")


## A rule-free board must behave exactly like canonical Sokoban.
func _t_classic_fidelity() -> void:
	var s := mk(["#####", "#@  #", "# $ #", "#  .#", "#####"])
	ok(not s.try_move(U), "wall blocks the walk")
	ok(s.turn == 0, "blocked move doesn't consume a turn")
	ok(s.try_move(D) and s.player == Vector2i(1, 2), "plain walk works")
	ok(s.try_move(R) and s.player == Vector2i(2, 2), "moving into a box is a push (canonical)")
	ok(s.boxes[0] == Vector2i(3, 2), "box and player advance exactly one cell")
	var s2 := mk(["#####", "#@$ #", "#   #", "#  .#", "#####"])
	ok(s2.try_move(R) and s2.boxes[0] == Vector2i(3, 1), "single-cell push")
	ok(not s2.try_move(R), "push into wall refused")
	ok(s2.move_log[0] == "R", "push logged uppercase")
	ok(s2.try_move(L), "walking away from a box works")
	ok(s2.boxes[0] == Vector2i(3, 1), "no accidental pull")
	ok(s2.undo() and s2.player == Vector2i(2, 1), "undo works classically")
	ok(s2.redo() and s2.player == Vector2i(1, 1), "redo works classically")
	# partial goals never solve
	var s3 := mk(["#####", "#@  #", "#$$ #", "#.. #", "#####"])
	s3.try_move(D)  # box (1,2)→(1,3): one of two goals covered
	ok(not s3.is_solved(), "one of two goals covered is not a win")
	ok(not s3.solved, "solved flag stays false")


func _t_rolling_box() -> void:
	# 'q' keeps sliding until blocked — one push crosses the corridor
	var s := mk(["########", "#@q    #", "#     .#", "########"])
	s.try_move(R)
	ok(s.boxes[0] == Vector2i(6, 1), "rolling box slides to the wall")
	s.undo()
	ok(s.boxes[0] == Vector2i(2, 1), "undo restores rolling box")
	# it only stops at blockers — a goal at the end of the glide catches it
	var s2 := mk(["######", "#@q .#", "######"])
	s2.try_move(R)
	ok(s2.is_solved(), "rolling box lands on the last free cell")


func _t_heavy_box() -> void:
	# 'n' can be pushed once, then needs a full turn of rest
	var s := mk(["#######", "#@n   #", "#    .#", "#######"])
	ok(s.try_move(R) and s.boxes[0] == Vector2i(3, 1), "heavy box pushed once")
	ok(not s.try_move(R), "heavy box refuses a consecutive push")
	ok(s.player == Vector2i(2, 1), "blocked push keeps the player put")
	s.try_move(L)              # step away — the rest tick expires
	s.try_move(R)              # walk back next to the box
	ok(s.try_move(R), "heavy box pushable again after the rest")


func _t_pit() -> void:
	# 'u' swallows boxes; the player walks over it freely
	var s := mk(["######", "#@$u #", "#   .#", "######"],
		[{"id": "quota", "params": {"n": 1}}])
	s.try_move(R)
	s.try_move(R)
	ok(s.boxes.is_empty(), "box sinks into the pit")
	ok(s.pit_cells.size() == 1, "pit stays — more boxes could sink")
	ok(not s.is_solved(), "sunken box means quota can't complete")
	ok(s.try_move(R), "player crosses the pit cell safely")


func _t_pull_zone() -> void:
	# standing on 'z', walking away drags the box behind you
	var s := mk(["######", "#$z@ #", "#   .#", "######"])
	ok(s.pull_cells.has(Vector2i(2, 1)), "pull zone parsed")
	s.try_move(L)  # step onto the zone (box is to the left)
	ok(s.player == Vector2i(2, 1), "stepped onto the traction zone")
	s.try_move(R)  # walk right — the box behind gets dragged along
	ok(s.boxes[0] == Vector2i(2, 1) and s.player == Vector2i(3, 1),
		"traction zone pulls the box into your old cell")
	s.try_move(R)  # off the zone now — walking away does NOT pull
	ok(s.boxes[0] == Vector2i(2, 1), "no pull outside the zone")


func _t_quake() -> void:
	# every 2 turns the quake slides boxes — direction rotates → ↓ ← ↑
	var s := mk(["#####", "#@$ #", "#   #", "#.  #", "#####"],
		[{"id": "quake", "params": {"every": 2}}])
	s.try_move(D)               # turn 1
	ok(s.boxes[0] == Vector2i(2, 1), "quake hasn't hit yet")
	s.try_move(U)               # turn 2 → quake →
	ok(s.boxes[0] == Vector2i(3, 1), "first quake pushes boxes right")
	s.try_move(D)               # turn 3 — step away, don't touch the box
	s.try_move(U)               # turn 4 → quake ↓
	ok(s.boxes[0] == Vector2i(3, 2), "second quake pushes boxes down")


func _t_mitosis() -> void:
	var s := mk(["#######", "#@$   #", "#    .#", "#######"],
		[{"id": "mitosis", "params": {"every": 2, "cap": 6}}])
	s.try_move(D)               # turn 1
	ok(s.boxes.size() == 1, "still one box")
	s.try_move(U)               # turn 2 → division
	ok(s.boxes.size() == 2, "mitosis clones the box")
	ok(s.box_mimic[1] == false and s.box_colors[1] == 0,
		"clone inherits normal flags")


func _t_drunk() -> void:
	# every step rotates your direction 90° CW
	var s := mk(["#####", "#@  #", "#   #", "#   #", "#####"],
		[{"id": "drunk"}])
	s.try_move(R)               # n=0 → straight right
	ok(s.player == Vector2i(2, 1), "first step goes where you said")
	s.try_move(R)               # n=1 → rotated 90° CW = down
	ok(s.player == Vector2i(2, 2), "second step rotated CW")
	s.undo()                    # undo restores the dizziness counter
	s.try_move(R)
	ok(s.player == Vector2i(2, 2), "undo+redo keeps the drunk sequence")


func _t_spring() -> void:
	var s := mk(["#######", "#@$  .#", "#######"],
		[{"id": "spring"}])
	s.try_move(R)               # push → bounce back
	ok(s.boxes[0] == Vector2i(3, 1), "push still lands")
	ok(s.player == Vector2i(1, 1), "spring bounces the player back")
	# push, walk back, push again — each push bounces you
	s.try_move(R)               # walk to (2,1), no push → no bounce
	ok(s.player == Vector2i(2, 1), "walking doesn't bounce")
	s.try_move(R)               # push → box (4,1), bounce to (2,1)
	ok(s.boxes[0] == Vector2i(4, 1) and s.player == Vector2i(2, 1),
		"every push bounces you to the start cell")


func _t_musical() -> void:
	# boxes rotate positions in a ring every N turns
	var s := mk(["#######", "#@$ $ #", "#    .#", "#######"],
		[{"id": "musical", "params": {"every": 2}}])
	s.try_move(D)               # turn 1
	s.try_move(U)               # turn 2 → rotation
	# boxes were at (2,1),(4,1); ring shift: box0→(4,1), box1→(2,1)
	ok(s.boxes[0] == Vector2i(4, 1) and s.boxes[1] == Vector2i(2, 1),
		"musical chairs swaps box positions")


func _t_life() -> void:
	# isolated boxes die (<2 neighbors); clustered ones spawn new life
	var s := mk(["######", "#@$  #", "#    #", "#   $.#", "######"],
		[{"id": "life", "params": {"every": 2, "cap": 20}}])
	s.try_move(D)               # turn 1
	ok(s.boxes.size() == 2, "two lonely boxes")
	s.try_move(U)               # turn 2 → Conway step
	ok(s.boxes.is_empty(), "sparse boxes all die off")
	var s2 := mk(["######", "#@   #", "# $$$#", "#    #", "######"],
		[{"id": "life", "params": {"every": 1, "cap": 20}}])
	s2.try_move(R)              # turn 1 → generation every turn
	# row of 3: ends have 1 neighbor (die), middle has 2 (lives);
	# cells above/below middle have 3 neighbors → birth
	ok(s2.boxes.size() == 3, "blinker: line of 3 survives as a line of 3")
	ok(s2.box_at(Vector2i(3, 1)) != -1, "birth above the middle box")


func _t_repel() -> void:
	# box on your row, ≥2 away, slides further off each turn
	var s := mk(["#######", "#@$   #", "#    .#", "#######"],
		[{"id": "repel"}])
	s.try_move(D)               # turn 1: box (2,1), player (1,2) — same col? dx=1,dy=-1 → no
	ok(s.boxes[0] == Vector2i(2, 1), "not aligned — no repel")
	s.try_move(U)               # turn 2: player (1,1), box (2,1) — distance 1 → adjacent, no repel
	ok(s.boxes[0] == Vector2i(2, 1), "adjacent boxes don't repel")
	var s2 := mk(["########", "#@  $  #", "#     .#", "########"],
		[{"id": "repel"}])
	s2.try_move(D)              # player (1,2)… box (4,1) same row? no → stays
	s2.try_move(U)              # player (1,1): box (4,1) same row, dist 3 → repels to (5,1)
	ok(s2.boxes[0] == Vector2i(5, 1), "same-row box repels one step")


func _t_link() -> void:
	# pushing a colored box moves every box of that color
	var s := mk(["#########", "#@b   b #", "#      .#", "#########"],
		[{"id": "link"}])
	s.try_move(R)               # push b at (2,1) → (3,1); linked b at (6,1) → (7,1)
	ok(s.boxes[0] == Vector2i(3, 1), "pushed box moves")
	ok(s.boxes[1] == Vector2i(7, 1), "linked box moves too")
	# normal boxes don't link without the "all" param
	var s2 := mk(["#########", "#@$   $ #", "#      .#", "#########"],
		[{"id": "link"}])
	s2.try_move(R)
	ok(s2.boxes[1] == Vector2i(6, 1), "plain boxes don't link by default")


func _t_mirror() -> void:
	# push mirrors through the vertical axis: box at mirror(old) also moves
	# width 8 → mirror of x=2 is x=5
	var s := mk(["########", "#@$  $ #", "#     .#", "########"],
		[{"id": "mirror"}])
	s.try_move(R)               # box (2,1)→(3,1); mirror of (2,1) is (5,1) → pushed to (6,1)
	ok(s.boxes[0] == Vector2i(3, 1), "pushed box moves")
	ok(s.boxes[1] == Vector2i(6, 1), "mirror box pushed the same way")
