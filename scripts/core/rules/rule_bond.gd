class_name BondRule
extends SokobanRule
## Pegamento (estilo Sokobond): cajas ortogonalmente adyacentes forman
## un bloque — empujas una y se mueve todo el bloque en esa dirección.


func _init(p_params: Dictionary = {}) -> void:
	super("bond", p_params)
	title = "Pegamento"
	description = "Las cajas que se tocan se mueven en bloque."


## Boxes orthogonally connected to box_idx (flood fill over box adjacency).
func _cluster(state, start: int) -> Array:
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for d in GameState.DIRS.values():
			var bi: int = state.box_at(state.boxes[i] + d)
			if bi != -1 and not seen.has(bi):
				seen[bi] = true
				stack.append(bi)
	return seen.keys()


func can_push(state, box_idx: int, dir: Vector2i) -> bool:
	# Clear last turn's cluster first: a plain push afterwards must not
	# replay the previous cluster in after_push.
	state.rule_state[id] = {}
	var cluster: Array = _cluster(state, box_idx)
	if cluster.size() <= 1:
		return true
	# Cells the cluster currently occupies (they vacate as a block).
	var cells := {}
	for i in cluster:
		cells[state.boxes[i]] = true
	# The engine moves the contiguous line from box_idx along dir itself;
	# the rest of the cluster is moved in after_push.
	var line := {}
	var scan: Vector2i = state.boxes[box_idx]
	var bi: int = state.box_at(scan)
	while bi != -1:
		line[bi] = true
		scan += dir
		bi = state.box_at(scan)
	for i in cluster:
		var dest: Vector2i = state.boxes[i] + dir
		if state.is_solid(dest):
			return false
		if state.has_box(dest) and not cells.has(dest):
			return false  # would hit a box outside the block
		# Boxes never rest on a filter: the matching color glides
		# through (after_push resolves it), any other color is denied.
		if state.filters.has(dest) \
				and int(state.box_colors[i]) != int(state.filters[dest]):
			return false
		# Portals: the exit must be free (or part of the moving block).
		if state._rule_on("portal") and state.portals.has(dest):
			var ex: Vector2i = state.portals[dest]
			if state.is_solid(ex) or (state.has_box(ex) and not cells.has(ex)):
				return false
		if dest == state.boxes[box_idx] and not line.has(i):
			return false  # would land on the player's next cell
		if state.one_way.has(state.boxes[i]) and state.one_way[state.boxes[i]] != dir:
			return false
		if state.rails.has(state.boxes[i]):
			var ax: Vector2i = state.rails[state.boxes[i]]
			if (ax.x != 0) != (dir.x != 0):
				return false
		# Per-box vetoes (push budgets) apply to cluster members too.
		for rule in state.rules:
			if rule != self and not rule.can_move(state, i, dir):
				return false
	state.rule_state[id] = {"cluster": cluster, "line": line}
	return true


func after_push(state, _box_idx: int, dir: Vector2i) -> void:
	var info: Dictionary = state.rule_state.get(id, {})
	var line: Dictionary = info.get("line", {})
	# Move cluster members front-to-back so box_step_dest sees cells
	# already vacated by the members ahead of them.
	var members: Array = info.get("cluster", [])
	members.sort_custom(func(a, b): return \
		state.boxes[int(a)].x * dir.x + state.boxes[int(a)].y * dir.y \
		> state.boxes[int(b)].x * dir.x + state.boxes[int(b)].y * dir.y)
	for i in members:
		# JSON round-trips degrade int keys to strings — coerce both.
		if not line.has(i) and not line.has(str(i)):
			var bi := int(i)
			var nd: Vector2i = state.box_step_dest(state.boxes[bi], dir)
			if nd != Vector2i(-1, -1):
				state.boxes[bi] = nd
				for rule in state.rules:
					if rule != self:
						rule.after_box_moved(state, bi, dir)


## Undo/save round-trips can leave float indices / string dict keys in
## rule_state — normalize back to ints.
func fix_state(state) -> void:
	var info: Dictionary = state.rule_state.get(id, {})
	if info.is_empty():
		return
	var line := {}
	for k in info.get("line", {}).keys():
		line[int(k)] = true
	var cluster: Array = []
	for v in info.get("cluster", []):
		cluster.append(int(v))
	state.rule_state[id] = {"cluster": cluster, "line": line}


static func describe() -> Dictionary:
	return {
		"title": "Pegamento",
		"description": "Las cajas adyacentes forman un bloque: se mueven todas juntas.",
	}
