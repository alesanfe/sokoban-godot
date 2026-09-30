class_name SokobanSolver
extends RefCounted
## Two engines:
##  - Classic levels: macro-search over pushes (player position normalized
##    to its reachable region), A* with a Hungarian box→goal assignment
##    heuristic and dead-square pruning.
##  - Ruled levels: per-step BFS over the real GameState engine, so
##    arbitrary rule plugins stay supported.
##
## Returns {"ok": bool, "moves": PackedStringArray, "states": int,
##          "reason": String}

const MAX_STATES := 60000
const INF := 1e9
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func solve(level: LevelData, max_states: int = MAX_STATES) -> Dictionary:
	var s0 := GameState.from_level_data(level)
	return solve_state(s0, max_states)


## Background solve (WorkerThreadPool) — the UI stays responsive while
## the solver runs; `cb` receives the result dict on the main loop.
static func solve_async(level: LevelData, cb: Callable, max_states: int = MAX_STATES) -> void:
	var lvl := LevelData.from_dict(level.to_dict())  # detached copy
	WorkerThreadPool.add_task(func():
		# the screen that requested the solve may be gone by now
		if cb.is_valid():
			cb.call_deferred(solve(lvl, max_states)), true)


## Same but mid-game: serializes the live state, solves it on a worker
## thread, calls `cb` on the main loop.
static func solve_state_async(state: GameState, cb: Callable, max_states: int = MAX_STATES) -> void:
	var data: Dictionary = state.serialize()
	# detach: the live level object must not cross the thread boundary
	var lvl := LevelData.from_dict(state.level_data.to_dict())
	WorkerThreadPool.add_task(func():
		var s := GameState.deserialize_state(lvl, data)
		var res := {"ok": false, "moves": PackedStringArray(), "states": 0,
			"reason": "estado inválido"} if s == null else solve_state(s, max_states)
		if cb.is_valid():
			cb.call_deferred(res), true)


static func solve_state(s0: GameState, max_states: int = MAX_STATES) -> Dictionary:
	if s0.is_solved():
		return {"ok": true, "moves": PackedStringArray(), "states": 0, "reason": ""}
	if _is_classic(s0):
		return _solve_classic(s0, max_states)
	return _solve_generic(s0, max_states)


static func _is_classic(s: GameState) -> bool:
	if not s.rules.is_empty() or not s.peekaboo_walls.is_empty() \
			or not s.switches.is_empty() or s.ghost_active \
			or not s.portals.is_empty() or not s.conveyors.is_empty() \
			or not s.key_cells.is_empty() or not s.door_cells.is_empty() \
			or not s.bomb_cells.is_empty() or not s.one_way.is_empty() \
			or not s.hole_cells.is_empty() or not s.fragile_cells.is_empty() \
			or not s.rails.is_empty() or s.lost \
			or not s.weak_walls.is_empty() or not s.swap_cells.is_empty() \
			or not s.pit_cells.is_empty() or not s.pull_cells.is_empty() \
			or not s.filters.is_empty() \
			or s.box_roll.has(true) or s.box_heavy.has(true) \
			or not s.twins.is_empty() \
			or not s.goal_colors.is_empty():
		return false
	for m in s.box_mimic:
		if m:
			return false
	for cc in s.box_colors:
		if cc != 0:
			return false
	return true


# ============================================================ generic BFS

static func _solve_generic(s0: GameState, max_states: int) -> Dictionary:
	var key0 := s0.canonical_key()
	var visited := {key0: true}
	var parent := {}
	var queue: Array = [[s0, key0]]
	var head := 0
	while head < queue.size():
		if visited.size() > max_states:
			return {"ok": false, "moves": PackedStringArray(), "states": visited.size(), "reason": "límite de estados"}
		var entry: Array = queue[head]
		queue[head] = null  # free the expanded state for GC
		head += 1
		var st: GameState = entry[0]
		for ch in GameState.DIR_CHARS:
			var c := st.clone_for_search()
			if not c.try_move(GameState.DIRS[ch]):
				continue
			var k := c.canonical_key()
			if visited.has(k):
				continue
			visited[k] = true
			parent[k] = [entry[1], ch]
			if c.solved:
				return {"ok": true, "moves": _reconstruct(parent, key0, k), "states": visited.size(), "reason": ""}
			if not c.lost:  # lost states never expand — don't enqueue
				queue.append([c, k])
		# Multiban: switching the active pusher is a solver action too.
		if not st.twins.is_empty():
			var c2 := st.clone_for_search()
			if c2.try_switch():
				var k2 := c2.canonical_key()
				if not visited.has(k2):
					visited[k2] = true
					parent[k2] = [entry[1], "s"]
					if c2.solved:
						return {"ok": true, "moves": _reconstruct(parent, key0, k2), "states": visited.size(), "reason": ""}
					if not c2.lost:
						queue.append([c2, k2])
	return {"ok": false, "moves": PackedStringArray(), "states": visited.size(),
		"reason": "irresoluble (espacio agotado)"}


# ============================================================ macro solver

static func _solve_classic(s0: GameState, max_states: int) -> Dictionary:
	if s0.goals.is_empty():
		# sin metas, "todas las cajas en metas" sería vacuamente cierto
		# tras el primer empujón y devolvería una solución espuria
		return {"ok": false, "moves": PackedStringArray(), "states": 0,
			"reason": "sin objetivos"}
	var floor_set := {}
	for y in s0.height:
		for x in s0.width:
			var pos := Vector2i(x, y)
			if s0.in_bounds(pos) and not s0.walls.has(pos):
				floor_set[pos] = true
	var alive := _dead_squares(s0, floor_set)
	var goals: Array = s0.goals.keys()
	var goals_set := _boxset(goals)
	# distance field per goal: goal -> {cell -> int}
	var dist := {}
	for g in goals:
		dist[g] = _bfs_field(g, floor_set)

	var start_boxes: Array = s0.boxes.duplicate()
	var start_reach := _reach(s0.player, _boxset(start_boxes), floor_set)
	var start_key := _macro_key(start_boxes, _rep(start_reach))
	var visited := {start_key: true}
	var parent := {}
	var heap := MinHeap.new()
	heap.push(0.0, {"boxes": start_boxes, "player": s0.player, "g": 0})
	while not heap.is_empty():
		if visited.size() > max_states:
			return {"ok": false, "moves": PackedStringArray(), "states": visited.size(), "reason": "límite de estados"}
		var node: Dictionary = heap.pop()
		var boxes: Array = node["boxes"]
		var bset := _boxset(boxes)
		var reach := _reach(node["player"], bset, floor_set)
		var rep := _rep(reach)
		var node_key := _macro_key(boxes, rep)
		for i in boxes.size():
			var b: Vector2i = boxes[i]
			for d in DIRS4:
				var stand: Vector2i = b - d
				var dest: Vector2i = b + d
				if not reach.has(stand) or not floor_set.has(dest) \
						or bset.has(dest) or not alive.has(dest):
					continue
				var nboxes := boxes.duplicate()
				nboxes[i] = dest
				var nbset := _boxset(nboxes)
				var nreach := _reach(b, nbset, floor_set)
				var nkey := _macro_key(nboxes, _rep(nreach))
				# dedupe BEFORE the expensive pruning: repeated states
				# skip the deadlock fixpoint and the Hungarian pass
				if visited.has(nkey):
					continue
				if _frozen_dead(nboxes, goals_set, floor_set):
					continue
				var h := _assign_cost(nboxes, goals, dist)
				if h >= INF:
					continue
				visited[nkey] = true
				var path := _path_to(reach, node["player"], stand)
				path.append(GameState.dir_char(d).to_upper())
				parent[nkey] = [node_key, path]
				var ng: int = node["g"] + path.size()
				if _all_on_goals(nbset, goals):
					return {"ok": true, "moves": _reconstruct(parent, start_key, nkey), "states": visited.size(), "reason": ""}
				# Weighted A*: heuristic dominates, slightly suboptimal
				# solutions but far fewer states on hard levels.
				heap.push(float(ng) + 2.0 * h, {"boxes": nboxes, "player": b, "g": ng})
	return {"ok": false, "moves": PackedStringArray(), "states": visited.size(),
		"reason": "irresoluble (espacio agotado)"}


## Set of walkable cells reachable by the player (value = parent info).
static func _reach(player: Vector2i, bset: Dictionary, floor_set: Dictionary) -> Dictionary:
	var reach := {player: [Vector2i(-1, -1), ""]}
	var q: Array[Vector2i] = [player]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if reach.has(n) or not floor_set.has(n) or bset.has(n):
				continue
			reach[n] = [c, GameState.dir_char(d)]
			q.append(n)
	return reach


## Canonical representative of a reachable region (smallest cell).
static func _rep(reach: Dictionary) -> Vector2i:
	var best := Vector2i(9999, 9999)
	for p in reach.keys():
		# lexicographic: width-agnostic (y*64+x collides at width >= 64)
		if p.y < best.y or (p.y == best.y and p.x < best.x):
			best = p
	return best


static func _boxset(boxes: Array) -> Dictionary:
	var s := {}
	for b in boxes:
		s[b] = true
	return s


static func _macro_key(boxes: Array, rep: Vector2i) -> String:
	var sb := boxes.duplicate()
	sb.sort()
	var parts := PackedStringArray()
	for b in sb:
		parts.append("%d,%d" % [b.x, b.y])
	return ";".join(parts) + "|" + str(rep)


## Walk path chars from `player` to `stand`, per the reach map.
static func _path_to(reach: Dictionary, player: Vector2i, stand: Vector2i) -> PackedStringArray:
	var rev := PackedStringArray()
	var cur := stand
	while cur != player:
		var e: Array = reach[cur]
		rev.append(e[1])
		cur = e[0]
	rev.reverse()
	return rev


static func _all_on_goals(bset: Dictionary, goals: Array) -> bool:
	for g in goals:
		if not bset.has(g):
			return false
	return true


## Freeze deadlock: a box is frozen if it can never be pushed again —
## for each axis, one side is wall/OOB/frozen-box. Any frozen box not on
## a goal means the state is unsolvable. Conservative fixpoint.
static func _frozen_dead(boxes: Array, goals_set: Dictionary, floor_set: Dictionary) -> bool:
	var frozen := {}
	var changed := true
	while changed:
		changed = false
		for b in boxes:
			if frozen.has(b):
				continue
			var blocked := func(c: Vector2i) -> bool:
				return not floor_set.has(c) or frozen.has(c)
			var hfrozen: bool = blocked.call(b + Vector2i(-1, 0)) or blocked.call(b + Vector2i(1, 0))
			var vfrozen: bool = blocked.call(b + Vector2i(0, -1)) or blocked.call(b + Vector2i(0, 1))
			if hfrozen and vfrozen:
				frozen[b] = true
				changed = true
	for b in boxes:
		if frozen.has(b) and not goals_set.has(b):
			return true
	return false


## BFS distance from a goal to every floor cell.
static func _bfs_field(goal: Vector2i, floor_set: Dictionary) -> Dictionary:
	var dist := {goal: 0}
	var q: Array[Vector2i] = [goal]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if dist.has(n) or not floor_set.has(n):
				continue
			dist[n] = dist[c] + 1
			q.append(n)
	return dist


## Hungarian min-cost matching boxes->goals on the distance matrix.
## Returns INF if some box can't reach any goal.
const MAX_ASSIGN := 96  # Hungarian is O(w^3) — cap crafted-level DoS


static func _assign_cost(boxes: Array, goals: Array, dist: Dictionary) -> int:
	var n := boxes.size()
	var m: int = goals.size()
	var w := maxi(n, m)
	if w > MAX_ASSIGN:
		return int(INF)  # too large to evaluate — treat as unreachable
	# cost[i][j]: box i -> goal j (dummy cols cost 0 when boxes > goals)
	var cost := []
	for i in n:
		var row := PackedFloat64Array()
		row.resize(w)
		for j in w:
			if j < m:
				var g: Vector2i = goals[j]
				var fld: Dictionary = dist[g]
				row[j] = float(fld.get(boxes[i], INF))
			else:
				row[j] = 0.0
		cost.append(row)
	# Hungarian (min assignment, n <= w always true here)
	var u := PackedFloat64Array(); u.resize(w + 1)
	var v := PackedFloat64Array(); v.resize(w + 1)
	var p := PackedInt32Array(); p.resize(w + 1)
	var way := PackedInt32Array(); way.resize(w + 1)
	for i in range(1, w + 1):
		p[0] = i
		var j0 := 0
		var minv := PackedFloat64Array(); minv.resize(w + 1); minv.fill(INF)
		var used := PackedByteArray(); used.resize(w + 1)
		while true:
			used[j0] = 1
			var i0: int = p[j0]
			var delta := INF
			var j1 := 0
			for j in range(1, w + 1):
				if used[j]:
					continue
				var cur: float = cost[i0 - 1][j - 1] - u[i0] - v[j] if i0 <= n else 0.0 - u[i0] - v[j]
				if cur < minv[j]:
					minv[j] = cur
					way[j] = j0
				if minv[j] < delta:
					delta = minv[j]
					j1 = j
			for j in range(0, w + 1):
				if used[j]:
					u[p[j]] += delta
					v[j] -= delta
				else:
					minv[j] -= delta
			j0 = j1
			if p[j0] == 0:
				break
		while j0 != 0:
			p[j0] = p[way[j0]]
			j0 = way[j0]
	var total := 0.0
	for j in range(1, w + 1):
		if p[j] <= n and p[j] != 0:
			var i0: int = p[j] - 1
			total += cost[i0][j - 1]
	return int(total)


## Cells from which no box can reach any goal (pull-BFS from goals).
static func _dead_squares(s: GameState, floor_set: Dictionary = {}) -> Dictionary:
	var alive := {}
	var queue: Array[Vector2i] = []
	for g in s.goals.keys():
		alive[g] = true
		queue.append(g)
	var fs: Dictionary = floor_set if not floor_set.is_empty() else _floor_of(s)
	while not queue.is_empty():
		var b: Vector2i = queue.pop_back()
		for d in DIRS4:
			var prev: Vector2i = b - d
			var stand: Vector2i = prev - d
			if alive.has(prev):
				continue
			if not fs.has(prev) or not fs.has(stand):
				continue
			alive[prev] = true
			queue.append(prev)
	return alive


## Public: floor cells where a dropped box can never reach a goal
## (the inverse of _dead_squares' "alive" set). Used by the UI as a
## deadlock warning overlay; only meaningful on classic levels.
static func dead_cells(s: GameState) -> Dictionary:
	var alive := _dead_squares(s)
	var floor_set := _floor_of(s)
	var dead := {}
	for c in floor_set.keys():
		if not alive.has(c):
			dead[c] = true
	return dead


## Public wrapper so the UI can decide whether deadlock overlay applies.
static func is_classic_state(s: GameState) -> bool:
	return _is_classic(s)


static func _floor_of(s: GameState) -> Dictionary:
	var f := {}
	for y in s.height:
		for x in s.width:
			var pos := Vector2i(x, y)
			if s.in_bounds(pos) and not s.walls.has(pos):
				f[pos] = true
	return f


static func _reconstruct(parent: Dictionary, k0: String, k: String) -> PackedStringArray:
	# Segments are multi-char paths (classic solver). Reversing the
	# flat char list would scramble each segment's internal order —
	# reverse at segment granularity instead.
	var segs := []
	while k != k0:
		var p: Array = parent[k]
		segs.append(p[1])
		k = p[0]
	segs.reverse()
	var rev := PackedStringArray()
	for seg in segs:
		if seg is PackedStringArray:
			for c in seg:
				rev.append(c)
		else:
			rev.append(seg)
	return rev


## Difficulty estimate 1-5 from solver stats.
static func rate_difficulty(result: Dictionary, level: LevelData) -> int:
	if not result.get("ok", false):
		return 0
	var moves: int = result.get("moves", PackedStringArray()).size()
	var states: int = result.get("states", 0)
	var boxes := 0
	for line in level.board:
		for ch in line:
			if TileSpec.is_box(ch):
				boxes += 1
	var score := moves * 1.0 + states / 60.0 + boxes * 3.0
	if not level.rules.is_empty():
		score *= 1.15 + 0.1 * level.rules.size()
	if score < 15:
		return 1
	if score < 40:
		return 2
	if score < 90:
		return 3
	if score < 200:
		return 4
	return 5


## Simple binary min-heap of {pri, value}.
class MinHeap:
	var items: Array = []

	func is_empty() -> bool:
		return items.is_empty()

	func push(pri: float, value) -> void:
		items.append([pri, value])
		var i := items.size() - 1
		while i > 0:
			var up := (i - 1) / 2
			if items[up][0] <= items[i][0]:
				break
			var t = items[up]
			items[up] = items[i]
			items[i] = t
			i = up

	func pop():
		var out = items[0][1]
		var last = items.pop_back()
		if not items.is_empty():
			items[0] = last
			var i := 0
			while true:
				var l := i * 2 + 1
				var r := l + 1
				var m := i
				if l < items.size() and items[l][0] < items[m][0]:
					m = l
				if r < items.size() and items[r][0] < items[m][0]:
					m = r
				if m == i:
					break
				var t = items[m]
				items[m] = items[i]
				items[i] = t
				i = m
		return out
