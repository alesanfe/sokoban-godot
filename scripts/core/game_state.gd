class_name GameState
extends RefCounted
## Deterministic Sokoban engine. Pure data + logic, no scene nodes.
## All rules hook into the move pipeline, so undo, replays and the
## solver all share exactly the same semantics.

const DIRS := {
	"l": Vector2i(-1, 0),
	"r": Vector2i(1, 0),
	"u": Vector2i(0, -1),
	"d": Vector2i(0, 1),
}
const DIR_CHARS := ["l", "r", "u", "d"]

## Position-keyed dictionaries (Vector2i keys): field name -> snapshot key.
## Snapshots, serialization, board transforms and canonical_key all
## iterate these tables, so a new tile type registers here exactly once.
const POS_FIELDS := {
	"walls": "walls",
	"peekaboo_walls": "peekaboo",
	"goals": "goals",
	"switches": "switches",
	"key_cells": "key_cells",
	"door_cells": "door_cells",
	"bomb_cells": "bomb_cells",
	"hole_cells": "hole_cells",
	"fragile_cells": "fragile_cells",
	"weak_walls": "weak_walls",
	"swap_cells": "swap_cells",
	"filters": "filters",
	"pit_cells": "pit_cells",
	"pull_cells": "pull_cells",
	"goal_colors": "goal_colors",
	"portal_kinds": "portal_kinds",
	"switch_pressed": "switch_pressed",
}
## Vector2i keys AND Vector2i values (portal pairs, belt dirs, gates).
const POS_VEC_FIELDS := {
	"portals": "portals",
	"conveyors": "conveyors",
	"rails": "rails",
	"one_way": "one_way",
}

var width: int = 0
var height: int = 0
var walls: Dictionary = {}          # Vector2i -> true
var peekaboo_walls: Dictionary = {} # Vector2i -> true (solid only when seen)
var goals: Dictionary = {}          # Vector2i -> true
var switches: Dictionary = {}       # Vector2i -> true (! = toggles rules)
var portals: Dictionary = {}        # Vector2i -> Vector2i (paired exits)
var portal_kinds: Dictionary = {}   # Vector2i -> "o" | "O" (for drawing/validation)
var conveyors: Dictionary = {}      # Vector2i -> Vector2i (belt direction)
var key_cells: Dictionary = {}      # Vector2i -> true ('k' pickups)
var door_cells: Dictionary = {}     # Vector2i -> true ('K'; erased when opened)
var bomb_cells: Dictionary = {}     # Vector2i -> true ('x'; box detonates)
var hole_cells: Dictionary = {}     # Vector2i -> true ('h'; box fills it, player falls)
var fragile_cells: Dictionary = {}  # Vector2i -> true ('f'; becomes a hole when left)
var rails: Dictionary = {}          # Vector2i -> Vector2i ('=' H axis / ':' V axis)
var weak_walls: Dictionary = {}     # Vector2i -> true ('W'; a push demolishes it)
var swap_cells: Dictionary = {}     # Vector2i -> true ('w'; box swaps with player)
var filters: Dictionary = {}        # Vector2i -> int (E/G/H: only that box color passes)
var twins: Array[Vector2i] = []     # 'p': extra pushers (Multiban, Space cycles)
var one_way: Dictionary = {}        # Vector2i -> Vector2i (only exit direction)
var lost: bool = false              # lethal move: fell into a hole / move limit hit
var lost_reason: String = ""
var keys_held: int = 0
var rules_enabled: bool = true      # switches flip this
var switch_pressed: Dictionary = {} # currently occupied switch cells
var boxes: Array[Vector2i] = []
var box_mimic: Array[bool] = []     # parallel to boxes: true = mimic box
var box_colors: Array[int] = []     # parallel to boxes: 0=normal, 1..3 = b/c/d
var box_roll: Array[bool] = []      # parallel: 'q' rolling boxes slide until blocked
var box_heavy: Array[bool] = []     # parallel: 'n' heavy boxes rest 1 turn after a push
var box_rest: Array[int] = []       # parallel: turns left before a heavy box moves again
var pit_cells: Dictionary = {}      # 'u' box pits: boxes sink, the player walks over
var pull_cells: Dictionary = {}     # 'z' traction zones: walking away drags a box
var goal_colors: Dictionary = {}    # Vector2i -> 1..3 (B/C/D); 0 = normal
var player: Vector2i = Vector2i.ZERO
var player_start: Vector2i = Vector2i.ZERO
# Transient per-turn data for rule hooks (not snapshotted).
var player_came_from := Vector2i(-1, -1)  # cell the player vacated this turn
var box_pushed_from := Vector2i(-1, -1)   # cell the pushed box vacated

var rules: Array = []               # Array[SokobanRule]
var rule_state: Dictionary = {}     # rule.id -> Dictionary (mutable per-rule data)

var ghost_active: bool = false
var ghost_pos: Vector2i = Vector2i(-1, -1)
var ghost_moves: PackedInt32Array = []  # indices into DIR_CHARS
var ghost_idx: int = 0

var turn: int = 0
var elapsed: float = 0.0
var move_log: PackedStringArray = []    # LURD chars; uppercase = push
var last_attempt: PackedStringArray = []# log of previous attempt (ghost source)
var history: Array = []                 # snapshots for undo
var redo_stack: Array = []              # move chars undone, for redo
var initial_snapshot: Dictionary = {}
## TileSpec flag → campo Dictionary de la celda (para el parser).
const CELL_FIELDS := {"switch": "switches", "key": "key_cells",
	"door": "door_cells", "bomb": "bomb_cells", "hole": "hole_cells",
	"fragile": "fragile_cells", "pit": "pit_cells", "pull": "pull_cells",
	"swap": "swap_cells"}

var level_data = null                   # LevelData, for reference
var solved: bool = false
var track_history: bool = true         # false on solver clones: no undo baggage
var _rule_ids := {}                    # rule id -> true, built at setup

signal changed
signal moved(pre_snapshot: Dictionary)  # fired after a consumed turn
signal fx_push(box_idx: int, dir: Vector2i)  # cosmetic hook for UI juice
signal fx_teleport(pos: Vector2i)     # cosmetic hook: portal exit flash


static func from_level_data(level) -> GameState:
	var s := GameState.new()
	s.level_data = level
	var board: PackedStringArray = level.board
	s.height = board.size()
	s.width = 0
	for line in board:
		s.width = maxi(s.width, line.length())
	for y in s.height:
		var line: String = board[y]
		for x in s.width:
			var ch := line[x] if x < line.length() else " "
			var sp := TileSpec.spec(ch)
			if sp.is_empty():
				continue
			var pos := Vector2i(x, y)
			if sp.get("wall", false):
				s.walls[pos] = true
			if sp.get("peekaboo", false):
				s.peekaboo_walls[pos] = true
			if sp.get("weak", false):
				s.weak_walls[pos] = true
			if sp.get("goal", false):
				s.goals[pos] = true
				if int(sp.get("gcolor", 0)) > 0:
					s.goal_colors[pos] = int(sp["gcolor"])
			if sp.get("box", false):
				s._add_box(pos, int(sp.get("bcolor", 0)),
					sp.get("mimic", false), sp.get("roll", false),
					sp.get("heavy", false))
			if sp.get("player", false):
				s.player = pos
			if sp.get("twin", false):
				s.twins.append(pos)
			if sp.has("portal"):
				s.portal_kinds[pos] = sp["portal"]
			if sp.has("conveyor"):
				s.conveyors[pos] = sp["conveyor"]
			if sp.has("rail"):
				s.rails[pos] = sp["rail"]
			if sp.has("one_way"):
				s.one_way[pos] = sp["one_way"]
			if sp.has("filter"):
				s.filters[pos] = int(sp["filter"])
			for flag in CELL_FIELDS:
				if sp.get(flag, false):
					s.get(CELL_FIELDS[flag])[pos] = true
	# Pair portal cells of the same kind in scan order.
	var pk := {}
	for p in s.portal_kinds.keys():
		var kind: String = s.portal_kinds[p]
		if not pk.has(kind):
			pk[kind] = []
		pk[kind].append(p)
	for kind in pk.keys():
		var cells: Array = pk[kind]
		for i in range(0, cells.size() - 1, 2):
			s.portals[cells[i]] = cells[i + 1]
			s.portals[cells[i + 1]] = cells[i]
	# overlays: cajas posadas sobre terreno que el charset no compone
	# (b sobre meta C, caja sobre cinta/portal/interruptor…). El char
	# ya poblaba el terreno; aquí solo llega el ocupante.
	for pos in level.over.keys():
		if not s.in_bounds(pos):
			continue
		var os: Dictionary = level.over[pos]
		# una celda que ya trae ocupante en su char (caja/jugador)
		# no admite segundo ocupante — el char gana
		if s.box_at(pos) != -1 or pos == s.player or s.twins.has(pos):
			continue
		s._add_box(pos, int(os.get("c", 0)), bool(os.get("m", false)),
			bool(os.get("r", false)), bool(os.get("h", false)))
	s.player_start = s.player
	for rdef in level.rules:
		var rid := str(rdef.get("id", ""))
		var rule = RuleRegistry.create(rid, _clamp_params(rid, rdef.get("params", {})))
		if rule:
			s.rules.append(rule)
			s._rule_ids[rid] = true
	for rule in s.rules:
		rule.setup(s)
	s.initial_snapshot = s._make_snapshot()
	return s


## Clamp rule params to their param_schema min/max — share codes and
## hand-edited JSON can carry out-of-range values the editor never emits.
static func _clamp_params(rid: String, params: Dictionary) -> Dictionary:
	var out := params.duplicate()
	for spec in RuleRegistry.param_schema(rid):
		var k: String = spec.get("key", "")
		if not out.has(k):
			continue
		var v = out[k]
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			continue
		out[k] = clampf(float(v), float(spec.get("min", -INF)), float(spec.get("max", INF)))
	return out


# ---------------------------------------------------------------- queries

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


## Appends a box keeping every parallel flag array in sync.
func _add_box(pos: Vector2i, color: int = 0, mimic: bool = false,
		roll: bool = false, heavy: bool = false) -> void:
	boxes.append(pos)
	box_colors.append(color)
	box_mimic.append(mimic)
	box_roll.append(roll)
	box_heavy.append(heavy)
	box_rest.append(0)


func _remove_box(i: int) -> void:
	boxes.remove_at(i)
	box_mimic.remove_at(i)
	box_colors.remove_at(i)
	box_roll.remove_at(i)
	box_heavy.remove_at(i)
	box_rest.remove_at(i)
	# Index-keyed rule state (e.g. push_limit counts) must follow the
	# surviving boxes, not the slots.
	for rule in rules:
		rule.on_box_removed(self, i)


func box_at(pos: Vector2i) -> int:
	for i in boxes.size():
		if boxes[i] == pos:
			return i
	return -1


func has_box(pos: Vector2i) -> bool:
	return box_at(pos) != -1


## Line of sight: same row/column as player, no normal wall or box between.
func can_see(pos: Vector2i) -> bool:
	if pos.x != player.x and pos.y != player.y:
		return false
	var step := Vector2i(signi(pos.x - player.x), signi(pos.y - player.y))
	var c := player + step
	while c != pos:
		if walls.has(c) or has_box(c) or peekaboo_walls.has(c):
			return false
		c += step
	return true


func is_solid(pos: Vector2i) -> bool:
	if walls.has(pos):
		return true
	if weak_walls.has(pos):
		return true
	if door_cells.has(pos):
		return true
	if peekaboo_walls.has(pos):
		return can_see(pos)
	return not in_bounds(pos)


func is_free_for_box(pos: Vector2i) -> bool:
	return not is_solid(pos) and not has_box(pos) and pos != player \
		and not twins.has(pos) \
		and not (ghost_active and pos == ghost_pos)


## True when rule `rid` is present and rules are enabled (switches !).
func _rule_on(rid: String) -> bool:
	return rules_enabled and _rule_ids.has(rid)


## Applies `map` to every position key on the board and `vec_map` to
## Vector2i values (directions) — used by RotateRule so no tile type
## can be forgotten when the board turns.
func transform_cells(map: Callable, vec_map: Callable) -> void:
	for fname in POS_FIELDS:
		var nd := {}
		var src: Dictionary = get(fname)
		for k in src.keys():
			nd[map.call(k)] = src[k]
		set(fname, nd)
	for fname in POS_VEC_FIELDS:
		var nd2 := {}
		var src2: Dictionary = get(fname)
		for k in src2.keys():
			nd2[map.call(k)] = vec_map.call(src2[k])
		set(fname, nd2)
	for i in boxes.size():
		boxes[i] = map.call(boxes[i])
	for i in twins.size():
		twins[i] = map.call(twins[i])
	player = map.call(player)
	player_start = map.call(player_start)
	if ghost_active:
		ghost_pos = map.call(ghost_pos)


func _modv(p: Vector2i) -> Vector2i:
	return Vector2i(((p.x % width) + width) % width, ((p.y % height) + height) % height)


func _is_edge_cell(p: Vector2i) -> bool:
	return p.x <= 0 or p.y <= 0 or p.x >= width - 1 or p.y >= height - 1


## Torus: scanning around the board for the first non-wall cell.
func _wrap_dest(from: Vector2i, d: Vector2i) -> Vector2i:
	var c := _modv(from + d)
	var guard := 0
	while walls.has(c) and guard < width * height:
		c = _modv(c + d)
		guard += 1
	return c


## Where a box ends after ONE step from `from` in direction `d`: edge
## wraparound (torus rule) and portal teleport applied. -1,-1 = blocked.
func box_step_dest(from: Vector2i, d: Vector2i) -> Vector2i:
	var dest := from + d
	if not is_free_for_box(dest):
		if _rule_on("torus") and (not in_bounds(dest) or (walls.has(dest) and _is_edge_cell(dest))):
			dest = _wrap_dest(from, d)
			if dest == from or not is_free_for_box(dest):
				return Vector2i(-1, -1)
		else:
			return Vector2i(-1, -1)
	if _rule_on("portal") and portals.has(dest):
		var ex: Vector2i = portals[dest]
		if is_free_for_box(ex):
			fx_teleport.emit(ex)
			return ex
		return Vector2i(-1, -1)
	# Colored filters (E/G/H): a box of the matching color glides through
	# consecutive filter cells; any other box (or none) bounces off.
	if filters.has(dest):
		var bi := box_at(from)
		if bi == -1 or int(box_colors[bi]) != int(filters[dest]):
			return Vector2i(-1, -1)
		var guard := width * height
		while filters.has(dest) and guard > 0:
			if has_box(dest):
				return Vector2i(-1, -1)  # a resting box blocks the glide
			dest += d
			guard -= 1
		if not is_free_for_box(dest):
			return Vector2i(-1, -1)
	return dest


func is_solved() -> bool:
	if rules_enabled:
		# Every rule with an opinion must agree (quota + blob combined
		# means BOTH conditions), not just the first one in the list.
		var any := false
		for rule in rules:
			var r = rule.win_check(self)
			if r != null:
				any = true
				if not r:
					return false
		if any:
			return true
	if goals.is_empty():
		return false
	for g in goals.keys():
		var bi := box_at(g)
		if bi == -1:
			return false
		# Colored goals require a box of the same color.
		var bcol := int(box_colors[bi]) if bi < box_colors.size() else 0
		if int(goal_colors.get(g, 0)) != bcol:
			return false
	return true


static func dir_char(d: Vector2i) -> String:
	for k in DIRS:
		if DIRS[k] == d:
			return k
	return "l"


# ---------------------------------------------------------------- turns

## Attempts a player move. Returns true if the turn was consumed.
func try_move(d: Vector2i) -> bool:
	if solved or lost:
		return false
	var input_dir := d  # replays log the INPUT dir; remap re-derives each time
	if rules_enabled:
		for rule in rules:
			if rule.remaps_move():
				d = rule.remap_move(self, d)
	var prev_player := player
	# One-way gates: you may only leave the cell in its arrow direction.
	if one_way.has(player) and one_way[player] != d:
		return false
	var target := player + d
	# Torus: crossing the border (out of bounds or an edge wall) wraps
	# you around to the first open cell on the far side.
	if _rule_on("torus") and (not in_bounds(target) or (walls.has(target) and _is_edge_cell(target))):
		target = _wrap_dest(player, d)
		if target == player:
			return false
	var box_idx := box_at(target)
	var pushed := false
	var push_dest := Vector2i(-1, -1)
	var snap := _make_snapshot() if track_history else {}
	player_came_from = prev_player
	box_pushed_from = Vector2i(-1, -1)
	if rules_enabled:
		for rule in rules:
			rule.before_move(self, d)
	if door_cells.has(target):
		# Doors are solid until opened: a key opens the cell for good.
		if keys_held <= 0:
			return false
		keys_held -= 1
		door_cells.erase(target)
		player = target
	elif box_idx != -1:
		var pr := _try_push(target, d, box_idx)
		if not pr["ok"]:
			return false
		pushed = pr["pushed"]
		push_dest = pr["dest"]
	elif is_solid(target) or filters.has(target):
		return false
	elif twins.has(target):
		# Multiban: walking into a partner swaps control (a turn).
		var ti := twins.find(target)
		twins[ti] = player
		player = target
	else:
		var wr := _try_step(target, d)
		if not wr["ok"]:
			return false
		target = wr["target"]
		pushed = wr["pushed"]
		push_dest = wr["dest"]
		box_idx = wr["box_idx"]
		player = target
	# Fragile floor collapses into a hole once you step off it.
	if prev_player != player and fragile_cells.has(prev_player):
		fragile_cells.erase(prev_player)
		hole_cells[prev_player] = true
	# Holes: the player falls in — the attempt is lost (undo/restart).
	if hole_cells.has(player):
		lost = true
		lost_reason = "Te caíste en un agujero."
	if track_history:
		history.append(snap)
	redo_stack.clear()
	# The log stores the INPUT direction: replays feed it through
	# remap_move again, so remapping rules (drunk) replay identically.
	move_log.append(dir_char(input_dir).to_upper() if pushed else dir_char(input_dir))
	_pickup_key()
	if rules_enabled:
		if pushed:
			for rule in rules:
				rule.after_push(self, box_idx, d)
		for rule in rules:
			rule.after_player_move(self, d, pushed)
	if ghost_active:
		_step_ghost()
	if rules_enabled:
		for rule in rules:
			rule.after_turn(self)
	# Rule hooks (spring bounce, conveyor, gravity) can move the player
	# after the earlier hole check — re-check so nobody stands on a hole.
	if not lost and hole_cells.has(player):
		lost = true
		lost_reason = "Te caíste en un agujero."
	turn += 1
	for i in box_rest.size():
		if box_rest[i] > 0:
			box_rest[i] -= 1  # heavy boxes cool down one turn
	_resolve_bombs()
	_resolve_holes()
	_resolve_swaps()
	_resolve_pits()
	_check_switches()
	_check_solved()
	if rules_enabled:
		for rule in rules:
			rule.on_turn_end(self)
	if pushed:
		# rules may have removed/moved boxes since the push resolved
		var fi := box_at(push_dest)
		if fi != -1:
			fx_push.emit(fi, d)
	moved.emit(snap)
	changed.emit()
	return true


## Push branch of try_move: chain build, vetoes and the actual slide.
## {"ok": false} = turn not consumed; demolish returns ok+pushed=false
## (turn consumed, nothing moved); success sets player/pushed/dest.
func _try_push(target: Vector2i, d: Vector2i, box_idx: int) -> Dictionary:
	var head: Vector2i = boxes[box_idx]
	# One-way under the pushed box: it can only leave along the gate.
	if one_way.has(head) and one_way[head] != d:
		return {"ok": false}
	if rules_enabled:
		for rule in rules:
			if not rule.can_push(self, box_idx, d):
				return {"ok": false}
	# Chain rule: contiguous rows of boxes are pushed together.
	var chain: Array[int] = [box_idx]
	var scan := target + d
	var bi := box_at(scan)
	while bi != -1:
		chain.append(bi)
		scan += d
		bi = box_at(scan)
	if chain.size() > 1 and not _rule_on("chain") and not _rule_on("bond"):
		return {"ok": false}
	# Rails: a box on a rail can only be pushed along the rail axis.
	for ci in chain:
		if rails.has(boxes[ci]):
			var ax: Vector2i = rails[boxes[ci]]
			if (ax.x != 0) != (d.x != 0):
				return {"ok": false}
	# Heavy boxes ('n') need a rest turn between pushes.
	for ci in chain:
		if ci < box_rest.size() and box_rest[ci] > 0:
			return {"ok": false}
	# One-way gates and per-box vetoes (push budgets) apply to every
	# chain member, not just the head.
	for ci in chain:
		if ci != box_idx and one_way.has(boxes[ci]) \
				and one_way[boxes[ci]] != d:
			return {"ok": false}
		if rules_enabled:
			for rule in rules:
				if not rule.can_move(self, ci, d):
					return {"ok": false}
	# Mid-chain members also respect filters: a wrong-color box can't
	# even enter the filter cell — the whole push is refused.
	for i in range(chain.size() - 2, -1, -1):
		var mid_dest: Vector2i = boxes[chain[i]] + d
		if filters.has(mid_dest) and chain[i] < box_colors.size() \
				and int(box_colors[chain[i]]) != int(filters[mid_dest]):
			return {"ok": false}
	var dest := _resolve_push(chain[chain.size() - 1], d)
	var demolish := Vector2i(-1, -1)
	if dest == Vector2i(-1, -1):
		# Weak wall: the push demolishes it (turn consumed, nothing moves).
		var front: Vector2i = boxes[chain[chain.size() - 1]] + d
		if chain.size() == 1 and weak_walls.has(front):
			demolish = front
		else:
			return {"ok": false}
	# the push tires every heavy box in the chain for a turn
	for ci in chain:
		if ci < box_heavy.size() and box_heavy[ci]:
			box_rest[ci] = 2  # tail decrement lands it at 1 next turn
	if demolish != Vector2i(-1, -1):
		weak_walls.erase(demolish)
		return {"ok": true, "pushed": false, "dest": Vector2i(-1, -1)}
	for i in range(chain.size() - 1, -1, -1):
		var bidx: int = chain[i]
		var np2: Vector2i = dest if i == chain.size() - 1 else boxes[bidx] + d
		# matching-color boxes glide through filter cells (they
		# never rest on one) — same rule as box_step_dest
		while i != chain.size() - 1 and filters.has(np2) \
				and not has_box(np2):
			np2 += d
		if i != chain.size() - 1 and _rule_on("portal") and portals.has(np2):
			var ex: Vector2i = portals[np2]
			if is_free_for_box(ex):
				np2 = ex
				fx_teleport.emit(ex)
		boxes[bidx] = np2
		if rules_enabled:
			for rule in rules:
				rule.after_box_moved(self, bidx, d)
	player = target
	box_pushed_from = target
	return {"ok": true, "pushed": true, "dest": dest}


## Walk branch of try_move: portals, then traction-zone drag.
## {"ok": false} = refused; else the (possibly teleported) target and
## whether a drag displaced a box.
func _try_step(target: Vector2i, d: Vector2i) -> Dictionary:
	var pushed := false
	var push_dest := Vector2i(-1, -1)
	var box_idx := -1
	# Portals: stepping onto one teleports you to its pair.
	if _rule_on("portal") and portals.has(target):
		var ex: Vector2i = portals[target]
		if is_solid(ex) or has_box(ex) or filters.has(ex) \
				or (ghost_active and ex == ghost_pos):
			return {"ok": false}
		target = ex
		fx_teleport.emit(ex)
	# Traction zone ('z'): walking away drags the box behind you.
	# A drag is a displacement: it respects can_push (a maxed-out
	# push_limit box can't be dragged either) and fires after_push.
	if pull_cells.has(player):
		var bi2 := box_at(player - d)
		var drag_ok := bi2 != -1
		if drag_ok and rules_enabled:
			for rule in rules:
				if not rule.can_push(self, bi2, d):
					drag_ok = false
		if drag_ok:
			box_pushed_from = player - d
			boxes[bi2] = player
			box_idx = bi2
			pushed = true
			push_dest = boxes[bi2]
			if rules_enabled:
				for rule in rules:
					rule.after_box_moved(self, bi2, d)
	return {"ok": true, "target": target, "pushed": pushed,
		"dest": push_dest, "box_idx": box_idx}


## Key tiles: walking over 'k' picks it up.
func _pickup_key() -> void:
	if key_cells.has(player):
		key_cells.erase(player)
		keys_held += 1


## Bomb tiles: any box pushed/moved onto 'x' detonates — box and bomb
## are both removed from the board.
func _resolve_bombs() -> void:
	if bomb_cells.is_empty():
		return
	for i in range(boxes.size() - 1, -1, -1):
		if bomb_cells.has(boxes[i]):
			bomb_cells.erase(boxes[i])
			_remove_box(i)


## Hole tiles: a box pushed onto 'h' fills it — box and hole vanish,
## leaving plain floor (SokobanOnline "modern" rule).
func _resolve_holes() -> void:
	if hole_cells.is_empty():
		return
	for i in range(boxes.size() - 1, -1, -1):
		if hole_cells.has(boxes[i]):
			hole_cells.erase(boxes[i])
			_remove_box(i)


## Pit tiles ('u'): a box pushed/moved over one sinks and is gone for
## good — pairs with the quota rule. The player walks over it safely.
func _resolve_pits() -> void:
	if pit_cells.is_empty():
		return
	for i in range(boxes.size() - 1, -1, -1):
		if pit_cells.has(boxes[i]):
			_remove_box(i)


## Swap tiles ('w'): a box landing on one trades places with the player.
func _resolve_swaps() -> void:
	if swap_cells.is_empty():
		return
	for i in boxes.size():
		if swap_cells.has(boxes[i]):
			var p := player
			player = boxes[i]
			boxes[i] = p
			fx_teleport.emit(player)
			_pickup_key()  # the swap may drop the player onto a key
	# the swap may drop the player into a hole
	if hole_cells.has(player):
		lost = true
		lost_reason = "El intercambio te dejó en un agujero."


## Multiban: switch the active pusher (Space). Consumes a turn so the
## move log stays deterministic for replays and the solver.
func try_switch() -> bool:
	if solved or lost or twins.is_empty():
		return false
	var snap := _make_snapshot() if track_history else {}
	# cyclic: active pusher goes to the back of the queue
	twins.append(player)
	player = twins.pop_front()
	if track_history:
		history.append(snap)
	redo_stack.clear()
	move_log.append("s")
	if rules_enabled:
		for rule in rules:
			rule.after_turn(self)
	turn += 1
	_check_switches()
	_check_solved()
	moved.emit(snap)
	changed.emit()
	return true


func _check_switches() -> void:
	if switches.is_empty():
		return
	var occupied := {}
	for pos in switches.keys():
		if pos == player or has_box(pos):
			occupied[pos] = true
	var fresh_press := false
	for pos in occupied.keys():
		if not switch_pressed.has(pos):
			fresh_press = true
	switch_pressed = occupied
	if fresh_press:
		rules_enabled = not rules_enabled


func _resolve_push(box_idx: int, d: Vector2i) -> Vector2i:
	var dest := Vector2i(-1, -1)
	var custom := false
	if rules_enabled:
		for rule in rules:
			if rule.overrides_push():
				dest = rule.resolve_push(self, box_idx, d)
				custom = true
				break
	if not custom:
		dest = box_step_dest(boxes[box_idx], d)
		# Rolling boxes ('q') keep sliding until something blocks them.
		if box_idx < box_roll.size() and box_roll[box_idx]:
			var guard := width * height
			while guard > 0:
				guard -= 1
				var nxt := box_step_dest(dest, d)
				if nxt == Vector2i(-1, -1):
					break
				dest = nxt
	return dest


func _step_ghost() -> void:
	if ghost_idx >= ghost_moves.size():
		return
	var gi: int = ghost_moves[ghost_idx]
	ghost_idx += 1
	if gi < 0 or gi >= DIR_CHARS.size():
		return  # 's' (twin switch) and unknowns: burn the turn, don't move
	var d: Vector2i = DIRS[DIR_CHARS[gi]]
	# The ghost replays INPUT dirs: remap them like the original move so
	# input-remapping rules (drunk) replay the same trajectory.
	if rules_enabled:
		for rule in rules:
			if rule.remaps_move():
				d = rule.remap_move(self, d)
	var target := ghost_pos + d
	if is_solid_ghost(target):
		return
	var bi := box_at(target)
	if bi != -1:
		# The recorded push teleported/glided/wrapped like any real push.
		box_pushed_from = target
		if rules_enabled:
			var can := true
			for rule in rules:
				if not rule.can_push(self, bi, d) \
						or not rule.can_move(self, bi, d):
					can = false
					break
			if not can:
				return
		var dest := box_step_dest(target, d)
		if dest != Vector2i(-1, -1):
			boxes[bi] = dest
			if rules_enabled:
				for rule in rules:
					rule.after_box_moved(self, bi, d)
					rule.after_push(self, bi, d)
			ghost_pos = target
	else:
		ghost_pos = target


func is_solid_ghost(pos: Vector2i) -> bool:
	# The ghost is intangible to the player but interacts with the world.
	return is_solid(pos)


func is_free_for_box_ghost(pos: Vector2i) -> bool:
	return not is_solid(pos) and not has_box(pos) and pos != player \
		and pos != ghost_pos and not twins.has(pos) \
		and not filters.has(pos)


func tick(dt: float) -> void:
	if solved:
		return
	elapsed += dt
	_check_solved()


func _check_solved() -> void:
	if not lost and not solved and is_solved():
		solved = true


# ---------------------------------------------------------------- history

func undo() -> bool:
	if history.is_empty():
		return false
	if _rule_on("iron"):
		return false  # Void Stranger style: no take-backs
	var cur := _make_snapshot()
	var snap: Dictionary = history.pop_back()
	_restore_snapshot(snap)
	var ch := move_log[move_log.size() - 1]
	move_log.resize(move_log.size() - 1)
	redo_stack.append({"snap": cur, "ch": ch})
	solved = false
	changed.emit()
	return true


func redo() -> bool:
	if redo_stack.is_empty():
		return false
	var e: Dictionary = redo_stack.pop_back()
	history.append(_make_snapshot())
	_restore_snapshot(e["snap"])
	move_log.append(e["ch"])
	_check_solved()
	changed.emit()
	return true


func restart() -> void:
	last_attempt = move_log.duplicate()
	_restore_snapshot(initial_snapshot)
	for rule in rules:
		rule.setup(self)
		rule.on_restart(self)
	turn = 0
	elapsed = 0.0
	move_log = PackedStringArray()
	history.clear()
	redo_stack.clear()
	solved = false
	changed.emit()


func _make_snapshot() -> Dictionary:
	var s := {}
	for fname in POS_FIELDS:
		s[POS_FIELDS[fname]] = get(fname).duplicate()
	for fname in POS_VEC_FIELDS:
		s[POS_VEC_FIELDS[fname]] = get(fname).duplicate()
	for k in ["lost", "lost_reason", "keys_held", "rules_enabled",
			"ghost_active", "ghost_pos", "ghost_idx", "turn", "elapsed",
			"width", "height", "player", "player_start"]:
		s[k] = get(k)
	s["roll"] = box_roll.duplicate()
	s["heavy"] = box_heavy.duplicate()
	s["rest"] = box_rest.duplicate()
	s["twins"] = twins.duplicate()
	s["boxes"] = boxes.duplicate()
	s["mimic"] = box_mimic.duplicate()
	s["colors"] = box_colors.duplicate()
	s["rule_state"] = rule_state.duplicate(true)
	s["ghost_moves"] = ghost_moves.duplicate()
	return s


func _restore_snapshot(snap: Dictionary) -> void:
	for fname in POS_FIELDS:
		set(fname, snap.get(POS_FIELDS[fname], {}).duplicate())
	for fname in POS_VEC_FIELDS:
		set(fname, snap.get(POS_VEC_FIELDS[fname], {}).duplicate())
	box_roll.assign(snap.get("roll", []))
	box_heavy.assign(snap.get("heavy", []))
	box_rest.assign(snap.get("rest", []))
	twins.assign(snap.get("twins", []))
	lost = bool(snap.get("lost", false))
	lost_reason = str(snap.get("lost_reason", ""))
	keys_held = int(snap.get("keys_held", 0))
	rules_enabled = bool(snap.get("rules_enabled", true))
	boxes.assign(snap.get("boxes", []))
	box_mimic.assign(snap.get("mimic", []))
	box_colors.assign(snap.get("colors", []))
	var pp = snap.get("player", player)
	player = pp if pp is Vector2i else player
	var ps = snap.get("player_start", player_start)
	player_start = ps if ps is Vector2i else player_start
	rule_state = snap.get("rule_state", {}).duplicate(true)
	_normalize_rule_state()
	ghost_active = bool(snap.get("ghost_active", false))
	var gp = snap.get("ghost_pos", Vector2i(-1, -1))
	ghost_pos = gp if gp is Vector2i else Vector2i(-1, -1)
	ghost_moves = PackedInt32Array(snap.get("ghost_moves", []))
	ghost_idx = int(snap.get("ghost_idx", 0))
	turn = int(snap.get("turn", 0))
	elapsed = float(snap.get("elapsed", 0.0))
	width = int(snap.get("width", width))
	height = int(snap.get("height", height))


## JSON round-trips degrade types (PackedInt32Array -> Array, int dict
## keys -> String). Let each rule repair its rule_state after a restore.
func _normalize_rule_state() -> void:
	for rule in rules:
		rule.fix_state(self)


func clone() -> GameState:
	var c := GameState.new()
	c.level_data = level_data
	c.rules = rules  # rules are stateless apart from params; shared is fine
	c._rule_ids = _rule_ids.duplicate()
	c.player_start = player_start
	c.last_attempt = last_attempt.duplicate()
	c._restore_snapshot(_make_snapshot())
	c.move_log = move_log.duplicate()
	c.history = history.duplicate()
	c.initial_snapshot = initial_snapshot.duplicate(true)
	c.solved = solved
	return c


## Lightweight clone for the solver: only what determines future
## evolution — no undo history, logs or initial snapshot.
func clone_for_search() -> GameState:
	var c := GameState.new()
	c.level_data = level_data
	c.rules = rules
	c._rule_ids = _rule_ids.duplicate()
	c.player_start = player_start
	c._restore_snapshot(_make_snapshot())
	c.solved = solved
	c.track_history = false
	return c


## Canonical key for solver dedupe. Includes everything that affects
## future evolution of the state (but not history/log).
## JSON-safe serialization of a snapshot (for mid-game saves).
static func _ser_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		var pos: Vector2i = k
		out["%d,%d" % [pos.x, pos.y]] = d[k] if d[k] is not Vector2i else "%d,%d" % [d[k].x, d[k].y]
	return out


static func _deser_dict(d: Dictionary, vec_values: bool = false) -> Dictionary:
	var out := {}
	for k in d.keys():
		var a: PackedStringArray = str(k).split(",")
		if a.size() < 2:
			continue  # malformed key in a corrupt save — skip the entry
		var pos := Vector2i(int(a[0]), int(a[1]))
		if vec_values:
			var b: PackedStringArray = str(d[k]).split(",")
			if b.size() < 2:
				continue
			out[pos] = Vector2i(int(b[0]), int(b[1]))
		else:
			out[pos] = d[k]
	return out


func serialize() -> Dictionary:
	var hist := []
	for s in history:
		hist.append(_ser_snapshot(s))
	return {
		"snap": _ser_snapshot(_make_snapshot()),
		"log": "".join(move_log),
		"history": hist,
		# ghost rule needs the previous attempt after a resume too
		"attempt": "".join(last_attempt),
	}


static func _ser_snapshot(snap: Dictionary) -> Dictionary:
	var s := snap.duplicate()
	for fname in POS_FIELDS:
		s[POS_FIELDS[fname]] = _ser_dict(s.get(POS_FIELDS[fname], {}))
	for fname in POS_VEC_FIELDS:
		s[POS_VEC_FIELDS[fname]] = _ser_dict(s.get(POS_VEC_FIELDS[fname], {}))
	var p: Vector2i = snap.player
	s["player"] = "%d,%d" % [p.x, p.y]
	var ps: Vector2i = snap.get("player_start", p)
	s["player_start"] = "%d,%d" % [ps.x, ps.y]
	var tl := PackedStringArray()
	for t in snap.get("twins", []):
		tl.append("%d,%d" % [t.x, t.y])
	s["twins"] = ";".join(tl)
	var gp: Vector2i = snap.ghost_pos
	s["ghost_pos"] = "%d,%d" % [gp.x, gp.y]
	var bx := []
	for b in snap.boxes:
		bx.append("%d,%d" % [b.x, b.y])
	s["boxes"] = bx
	s["ghost_moves"] = Array(snap.ghost_moves)
	return s


static func deserialize_state(level: LevelData, data: Dictionary) -> GameState:
	var raw = data.get("snap")
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var snap := _deser_snapshot(raw)
	if typeof(snap.get("player")) != TYPE_VECTOR2I or \
			typeof(snap.get("boxes")) != TYPE_ARRAY:
		return null
	var s := GameState.from_level_data(level)
	s._restore_snapshot(snap)
	s.move_log = PackedStringArray(str(data.get("log", "")).split(""))
	var hist: Array = []
	for h in data.get("history", []):
		if h is Dictionary:
			hist.append(_deser_snapshot(h))
	s.history = hist
	s.last_attempt = PackedStringArray(
		str(data.get("attempt", "")).split("", false))
	s._check_solved()
	return s


static func _deser_snapshot(snap: Dictionary) -> Dictionary:
	var s := snap.duplicate()
	for fname in POS_FIELDS:
		s[POS_FIELDS[fname]] = _deser_dict(s.get(POS_FIELDS[fname], {}))
	for fname in POS_VEC_FIELDS:
		s[POS_VEC_FIELDS[fname]] = _deser_dict(s.get(POS_VEC_FIELDS[fname], {}), true)
	var p: PackedStringArray = str(s.get("player", "")).split(",")
	if p.size() == 2:
		s["player"] = Vector2i(int(p[0]), int(p[1]))
	var psa: PackedStringArray = str(s.get("player_start", "")).split(",")
	if psa.size() == 2:
		s["player_start"] = Vector2i(int(psa[0]), int(psa[1]))
	var tl2: Array[Vector2i] = []
	for t in str(s.get("twins", "")).split(";", false):
		var tp: PackedStringArray = t.split(",")
		if tp.size() == 2:
			tl2.append(Vector2i(int(tp[0]), int(tp[1])))
	s["twins"] = tl2
	var g: PackedStringArray = str(s.get("ghost_pos", "")).split(",")
	if g.size() == 2:
		s["ghost_pos"] = Vector2i(int(g[0]), int(g[1]))
	var bx: Array[Vector2i] = []
	for b in s.get("boxes", []):
		var a: PackedStringArray = str(b).split(",")
		if a.size() == 2:
			bx.append(Vector2i(int(a[0]), int(a[1])))
	s["boxes"] = bx
	# JSON loses typed arrays: restore Array[bool]/Array[int] or the
	# typed assignment in _restore_snapshot fails.
	var mim: Array[bool] = []
	for v in s.get("mimic", []):
		mim.append(bool(v))
	s["mimic"] = mim
	var cols: Array[int] = []
	for v in s.get("colors", []):
		cols.append(int(v))
	s["colors"] = cols
	var rl: Array[bool] = []
	for v in s.get("roll", []):
		rl.append(bool(v))
	s["roll"] = rl
	var hv: Array[bool] = []
	for v in s.get("heavy", []):
		hv.append(bool(v))
	s["heavy"] = hv
	var rs: Array[int] = []
	for v in s.get("rest", []):
		rs.append(int(v))
	s["rest"] = rs
	s["ghost_moves"] = PackedInt32Array(s.get("ghost_moves", []))
	return s


## Sorted "k=v" (or "k" for flag dicts) fragment of a position-keyed
## dictionary — shared by canonical_key segments.
static func _dict_frag(d: Dictionary) -> String:
	var ks := PackedStringArray()
	for k in d.keys():
		var v: Variant = d[k]
		if v is float and v == floorf(v):
			v = int(v)  # JSON round-trips degrade ints to floats
		ks.append(str(k) if v is bool else "%s=%s" % [k, v])
	ks.sort()
	return ",".join(ks)


func canonical_key() -> String:
	var parts := PackedStringArray()
	parts.append(str(player))
	var tk2 := PackedStringArray()
	for t in twins:
		tk2.append(str(t))
	# NO ordenar: try_switch consume twins[0] — el orden de la cola es
	# estado real (dos estados con el mismo conjunto en otro orden no
	# son equivalentes para el solver).
	parts.append("tw" + ",".join(tk2))
	var bx := PackedStringArray()
	for i in boxes.size():
		bx.append("%d,%d%s%d%s" % [boxes[i].x, boxes[i].y,
			"m" if box_mimic[i] else "",
			box_colors[i] if i < box_colors.size() else 0,
			("r" if box_roll[i] else "") +
			("h%d" % box_rest[i] if box_heavy[i] else "")])
	parts.append(";".join(bx))
	parts.append(str(ghost_pos) + ":" + str(ghost_idx))
	# Turn-phased rules (quake, musical, rotate, mitosis, life…) evolve
	# differently per turn parity: the turn must distinguish states.
	if not rules.is_empty():
		parts.append("turn:%d" % turn)
	for rule in rules:
		parts.append(rule.state_key(self))
	parts.append("m:%s:%d:%d" % [rules_enabled, keys_held, int(lost)])
	for fname in POS_FIELDS:
		parts.append(fname + "=" + _dict_frag(get(fname)))
	for fname in POS_VEC_FIELDS:
		parts.append(fname + "=" + _dict_frag(get(fname)))
	parts.append("%dx%d" % [width, height])
	return "|".join(parts)
