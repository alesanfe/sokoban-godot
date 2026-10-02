class_name BoardView
extends Node2D
## Draws a GameState as colored tiles + glyphs. No assets needed.
## Animates entity movement via the state's `moved` signal.

const COL_FLOOR := Color(0.13, 0.14, 0.17)
const COL_VOID := Color(0.05, 0.05, 0.07)
const COL_WALL := Color(0.36, 0.38, 0.45)
const COL_WALL_TOP := Color(0.48, 0.5, 0.58)
const COL_PEEK_SOLID := Color(0.55, 0.4, 0.6)
const COL_PEEK_GHOST := Color(0.55, 0.4, 0.6, 0.25)
const COL_GOAL := Color(0.25, 0.7, 0.35)
const COL_BOX := Color(0.72, 0.5, 0.24)
const COL_BOX_ON_GOAL := Color(0.45, 0.78, 0.4)
const COL_MIMIC := Color(0.7, 0.35, 0.85)
const COL_PLAYER := Color(0.95, 0.8, 0.2)
const COL_PLAYER2 := Color(0.95, 0.5, 0.15)
const COL_GHOST := Color(0.4, 0.8, 0.9, 0.35)
const COL_GRID := Color(1, 1, 1, 0.05)
const COL_SWITCH_ON := Color(0.3, 0.85, 0.5)
const COL_SWITCH_OFF := Color(0.85, 0.35, 0.35)
const COL_HINT := Color(0.3, 0.9, 0.9, 0.8)
const COL_KEY := Color(0.95, 0.85, 0.3)
const COL_DOOR := Color(0.5, 0.32, 0.2)
const COL_BOMB := Color(0.16, 0.16, 0.18)
const COL_ONEWAY := Color(0.8, 0.6, 0.9, 0.55)
const COL_FLASH := Color(0.9, 0.95, 1.0, 0.55)
const BOX_COLORS := [Color(0.72, 0.5, 0.24), Color(0.3, 0.55, 0.95),
	Color(0.95, 0.55, 0.2), Color(0.65, 0.4, 0.95)]
const GOAL_COLORS := [Color(0.25, 0.7, 0.35), Color(0.3, 0.55, 0.95),
	Color(0.95, 0.55, 0.2), Color(0.65, 0.4, 0.95)]
# Okabe–Ito: deuteranopia/protanopia-safe
const BOX_COLORS_CB := [Color(0.72, 0.5, 0.24), Color(0.0, 0.45, 0.7),
	Color(0.9, 0.62, 0.0), Color(0.8, 0.47, 0.65)]
const GOAL_COLORS_CB := [Color(0.0, 0.62, 0.45), Color(0.0, 0.45, 0.7),
	Color(0.9, 0.62, 0.0), Color(0.8, 0.47, 0.65)]
const ONEWAY_DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const ANIM_DUR := 0.13

# Kenney Sokoban (CC0) sprites — lazily loaded; procedural fallback
# when assets are absent (e.g. source checkout without assets/).
const TEX_DIR := "res://assets/kenney_sokoban/PNG/Retina/"
const TEX := {
	"floor": "Ground/ground_06.png",
	"wall": "Blocks/block_06.png",
	"box": "Crates/crate_02.png",
	"box_on_goal": "Crates/crate_16.png",
	"player": "Player/player_05.png",
	"goal": "Environment/environment_03.png",
	"box_b": "Crates/crate_04.png",
	"box_c": "Crates/crate_03.png",
	"box_d": "Crates/crate_05.png",
	"weak_wall": "Blocks/block_01.png",
	"filter": "Environment/environment_08.png",  # diamond — tinted per color
	"dark_tile": "Environment/environment_15.png",
	"warn": "Environment/environment_11.png",
	"twin": "Player/player_02.png",
}
static var _tex: Dictionary = {}
static var _skin := -1  # 0 sprites, 1 flat (procedural), 2 retro (tinted)


## Reloads the cached board skin — call after changing `board_skin`.
static func reload_skin() -> void:
	_skin = int(Storage.get_setting("board_skin"))


static func _skin_mode() -> int:
	if _skin < 0:
		reload_skin()
	return _skin


static func tex(name: String) -> Texture2D:
	if _skin_mode() == 1:
		return null  # "Plano" skin: always the procedural look
	if not _tex.has(name):
		var path: String = TEX_DIR + TEX[name]
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]

var state: GameState
var tile: float = 48.0
var hint_dir := Vector2i.ZERO  # arrow hint shown at player cell
var anchor := Vector2.ZERO     # base position; screen shake adds an offset
var trail_cells: Dictionary = {}  # breadcrumb route of the best saved replay
var show_dead := false         # deadlock warning overlay (classic levels)
var reduce_motion := false     # accessibility: no squash/shake

var _dead: Dictionary = {}     # cells where a box can never reach a goal
var _flashes: Array = []       # teleport flashes: [{pos: Vector2i, t: float}]
var _puffs: Array = []         # push dust: [{pos: Vector2i, t: float}]
var _cb := false               # colorblind-safe palette (Okabe–Ito)
var _last_dir := Vector2i(0, 1)  # player facing for the eyes
var _time := 0.0               # goal pulse clock
var _anim_t := 1.0
var _anim_prev := {}  # player/boxes/ghost positions before the move
var _squash_i := -1
var _squash_d := Vector2i.ZERO
var _squash_t := 1.0
var _shake := 0.0


func _init(p_state: GameState = null) -> void:
	if p_state:
		set_state(p_state)


func set_state(s: GameState) -> void:
	if state and state.moved.is_connected(_on_moved):
		state.moved.disconnect(_on_moved)
	if state and state.fx_push.is_connected(_on_fx_push):
		state.fx_push.disconnect(_on_fx_push)
	if state and state.fx_teleport.is_connected(_on_fx_teleport):
		state.fx_teleport.disconnect(_on_fx_teleport)
	if state and state.changed.is_connected(queue_redraw):
		state.changed.disconnect(queue_redraw)
	state = s
	if state:
		state.moved.connect(_on_moved)
		state.fx_push.connect(_on_fx_push)
		state.fx_teleport.connect(_on_fx_teleport)
		state.changed.connect(queue_redraw)
	reduce_motion = bool(Storage.get_setting("reduce_motion"))
	_cb = UiTheme.current_mode() == "cb"
	_anim_t = 1.0
	_squash_i = -1
	_squash_t = 1.0
	_shake = 0.0
	_last_dir = Vector2i(0, 1)
	hint_dir = Vector2i.ZERO
	trail_cells.clear()
	_flashes.clear()
	_puffs.clear()
	_refresh_dead()


func _refresh_dead() -> void:
	var classic := state != null and SokobanSolver.is_classic_state(state)
	# level 1 needs the map too: the push alarm reads it without drawing
	var assist := int(Storage.get_setting("deadlock_assist"))
	_dead = SokobanSolver.dead_cells(state) \
		if classic and assist >= 1 else {}
	# assist level 2+ shows the overlay; level 1 only uses it for the alarm
	show_dead = classic and assist >= 2


## Public read of the deadlock map (GameScreen uses it for the
## push alarm and the level-3 blocking assist).
func is_dead_cell(pos: Vector2i) -> bool:
	return _dead.has(pos)


func dead_cells() -> Dictionary:
	return _dead


func _on_fx_push(idx: int, d: Vector2i) -> void:
	if reduce_motion:
		return
	# idx is -1 when a rule consumed the pushed box (no squash target).
	_squash_i = idx if idx >= 0 else -1
	_squash_d = d
	_squash_t = 0.0
	_shake = 1.0
	if idx >= 0 and idx < state.boxes.size():
		var bpos: Vector2i = state.boxes[idx]
		_puffs.append({"pos": bpos, "t": 0.0,
			"goal": state.goals.has(bpos)})
		queue_redraw()


## Win cascade: staggered flash on every goal cell (called on solve).
func win_fx() -> void:
	if reduce_motion:
		return
	var i := 0
	for g in state.goals.keys():
		_flashes.append({"pos": g, "t": -0.08 * i, "col": Color(0.95, 0.85, 0.3, 0.7)})
		i += 1
	queue_redraw()


## Light visual nudge for a denied move (Juicee-lite), no game effect.
func deny_fx() -> void:
	if not reduce_motion:
		_shake = maxf(_shake, 0.45)


func _on_fx_teleport(pos: Vector2i) -> void:
	_flashes.append({"pos": pos, "t": 0.0})
	queue_redraw()


func _on_moved(pre: Dictionary) -> void:
	if int(pre.get("width", -1)) != state.width or (pre.get("boxes", []) as Array).size() != state.boxes.size():
		return  # board resized (rotation) or boxes teleported: snap
	# reduce_motion: el slide de 130ms por paso era el único tween que
	# no respetaba la preferencia — posición directa al destino
	if reduce_motion:
		return
	_anim_prev = pre
	_anim_t = 0.0
	var pd: Vector2i = state.player - Vector2i(pre.get("player", state.player))
	if pd != Vector2i.ZERO:
		_last_dir = pd.sign()


func _process(dt: float) -> void:
	if state == null:
		return
	var busy := false
	_time += dt
	if _anim_t < 1.0:
		_anim_t = minf(1.0, _anim_t + dt / ANIM_DUR)
		busy = true
	if _squash_t < 1.0:
		_squash_t = minf(1.0, _squash_t + dt / 0.18)
		busy = true
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt * 7.0)
		position = anchor + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 3.0
	else:
		position = anchor
	if not _flashes.is_empty():
		for i in range(_flashes.size() - 1, -1, -1):
			_flashes[i]["t"] += dt
			if _flashes[i]["t"] > 0.35:
				_flashes.remove_at(i)
		busy = true
	if not _puffs.is_empty():
		for i in range(_puffs.size() - 1, -1, -1):
			_puffs[i]["t"] += dt
			if _puffs[i]["t"] > 0.3:
				_puffs.remove_at(i)
		busy = true
	# pulsing goals need continuous redraws while any goal is free
	if not reduce_motion:
		for g in state.goals.keys():
			if not state.boxes.has(g):
				busy = true
				break
	if busy or _shake > 0.0:
		queue_redraw()


func _eased() -> float:
	var t := _anim_t
	return t * t * (3.0 - 2.0 * t)


func _pos_for(key, cur: Vector2) -> Vector2:
	if _anim_t < 1.0:
		var from = null
		if key is int:
			var pb: Array = _anim_prev.get("boxes", [])
			if key < pb.size():
				from = pb[key]
		elif key == "player":
			from = _anim_prev.get("player")
		elif key == "ghost":
			from = _anim_prev.get("ghost_pos")
		if from != null:
			# teleport (portal/wind across the map): snap, don't slide
			# a sprite through walls for a move that wasn't a step
			if cur.distance_to(Vector2(from)) > 1.5:
				return cur
			return cur.lerp(Vector2(from), 1.0 - _eased())
	return cur


func board_pixel_size() -> Vector2:
	if state == null:
		return Vector2.ZERO
	return Vector2(state.width, state.height) * tile


func _draw() -> void:
	if state == null:
		return
	var font := ThemeDB.fallback_font
	var fs := int(tile * 0.5)
	var wtex := tex("wall")
	var ftex := tex("floor")
	var gtex := tex("goal")
	for y in state.height:
		for x in state.width:
			var pos := Vector2i(x, y)
			var r := Rect2(x * tile, y * tile, tile, tile)
			var is_wall: bool = state.walls.has(pos)
			var is_peek: bool = state.peekaboo_walls.has(pos)
			var solid: bool = state.is_solid(pos)
			if is_wall:
				if wtex != null:
					draw_texture_rect(wtex, r, false)
				else:
					draw_rect(r, COL_WALL)
					draw_rect(Rect2(r.position, Vector2(tile, tile * 0.18)), COL_WALL_TOP)
					# bottom edge → depth cue
					draw_rect(Rect2(r.position + Vector2(0, tile * 0.86), Vector2(tile, tile * 0.14)), COL_WALL.darkened(0.45))
			elif is_peek:
				draw_rect(r, COL_PEEK_SOLID if solid else COL_PEEK_GHOST)
				_glyph(font, "?", r, Color.WHITE if solid else Color(1, 1, 1, 0.35), fs)
			elif state.in_bounds(pos):
				if ftex != null:
					draw_texture_rect(ftex, r, false, Color(1, 1, 1, 0.92))
				else:
					draw_rect(r, COL_FLOOR)
					if (x + y) % 2 == 0:  # subtle checker so floor ≠ void
						draw_rect(r, Color(1, 1, 1, 0.02))
			else:
				draw_rect(r, COL_VOID)
			if ftex == null or wtex == null:
				draw_rect(r, COL_GRID, false, 1.0)
			if state.goals.has(pos):
				var c := r.get_center()
				var gci := int(state.goal_colors.get(pos, 0))
				var pal: Array = GOAL_COLORS_CB if _cb else GOAL_COLORS
				var gcol: Color = pal[gci] if gci < pal.size() else COL_GOAL
				# pulse on free goals — attracts the eye to what remains
				var pulse := 1.0
				if not reduce_motion and not state.boxes.has(pos):
					pulse = 1.0 + 0.12 * sin(_time * 4.0 + float(pos.x + pos.y) * 0.7)
				if gtex != null:
					var gr := r.grow(-tile * 0.05)
					gr.size *= pulse
					gr.position = c - gr.size / 2
					draw_texture_rect(gtex, gr, false, Color(gcol, 0.9))
				else:
					draw_circle(c, tile * 0.16 * pulse, gcol)
				draw_arc(c, tile * 0.28 * pulse, 0, TAU, 24, gcol, 2.0)
				if gci > 0:
					_glyph(font, "BCD"[gci - 1], r, gcol.lightened(0.3), fs)
			if state.key_cells.has(pos):
				var c := r.get_center()
				draw_arc(c + Vector2(-tile * 0.12, 0), tile * 0.12, 0, TAU, 16, COL_KEY, 2.5)
				draw_line(c, c + Vector2(tile * 0.26, 0), COL_KEY, 2.5)
				draw_line(c + Vector2(tile * 0.18, 0), c + Vector2(tile * 0.18, tile * 0.12), COL_KEY, 2.0)
				draw_line(c + Vector2(tile * 0.26, 0), c + Vector2(tile * 0.26, tile * 0.1), COL_KEY, 2.0)
			if state.door_cells.has(pos):
				draw_rect(r.grow(-2), COL_DOOR)
				draw_rect(r.grow(-2), COL_DOOR.darkened(0.4), false, 2.0)
				draw_circle(r.get_center(), tile * 0.09, Color(0.1, 0.1, 0.1))
				_glyph(font, "K", r, Color(0.95, 0.85, 0.3), fs)
			if state.bomb_cells.has(pos):
				var c := r.get_center()
				draw_circle(c, tile * 0.26, COL_BOMB)
				draw_circle(c, tile * 0.26, Color(0.3, 0.3, 0.35), false, 2.0)
				draw_line(c + Vector2(tile * 0.1, -tile * 0.18), c + Vector2(tile * 0.22, -tile * 0.3), Color(0.6, 0.5, 0.3), 2.0)
				draw_circle(c + Vector2(tile * 0.24, -tile * 0.32), tile * 0.05, Color(0.95, 0.7, 0.2))
			if state.one_way.has(pos):
				var c := r.get_center()
				var dv := Vector2(state.one_way[pos])
				var s := Vector2(-dv.y, dv.x) * tile * 0.2
				draw_colored_polygon(PackedVector2Array(
					[c + dv * tile * 0.34, c - dv * tile * 0.1 + s, c - dv * tile * 0.1 - s]),
					COL_ONEWAY)
				draw_arc(c, tile * 0.36, 0, TAU, 20, COL_ONEWAY, 1.5)
			if state.hole_cells.has(pos):
				var ht := tex("dark_tile")
				if ht != null:
					draw_texture_rect(ht, r, false, Color(0.55, 0.55, 0.65))
				var c := r.get_center()
				draw_circle(c, tile * 0.34, Color(0.02, 0.02, 0.04))
				draw_circle(c, tile * 0.34, Color(0.45, 0.4, 0.55, 0.7), false, 2.0)
				draw_circle(c + Vector2(-tile * 0.08, -tile * 0.08), tile * 0.18, Color(0, 0, 0))
			if state.fragile_cells.has(pos):
				var c := r.get_center()
				draw_rect(r, Color(0.35, 0.3, 0.22, 0.35))
				var wt2 := tex("warn")
				if wt2 != null:
					draw_texture_rect(wt2,
						Rect2(c - Vector2.ONE * tile * 0.22,
							Vector2.ONE * tile * 0.44), false, Color(1, 1, 1, 0.85))
				else:
					# cracked-glass lines warn that it collapses underfoot
					draw_line(r.position + Vector2(3, 3), c, Color(0.8, 0.75, 0.6, 0.6), 1.5)
					draw_line(r.position + Vector2(r.size.x - 4, 4), c, Color(0.8, 0.75, 0.6, 0.6), 1.5)
					draw_line(c, c + Vector2(tile * 0.3, tile * 0.28), Color(0.8, 0.75, 0.6, 0.6), 1.5)
					draw_line(c, c + Vector2(-tile * 0.28, tile * 0.3), Color(0.8, 0.75, 0.6, 0.6), 1.5)
			if state.rails.has(pos):
				var c := r.get_center()
				var dv := Vector2(state.rails[pos])
				var s := Vector2(-dv.y, dv.x) * tile * 0.28
				draw_line(c - dv * tile * 0.42 + s, c + dv * tile * 0.42 + s, Color(0.6, 0.62, 0.7, 0.8), 2.5)
				draw_line(c - dv * tile * 0.42 - s, c + dv * tile * 0.42 - s, Color(0.6, 0.62, 0.7, 0.8), 2.5)
			if state.weak_walls.has(pos):
				var wt := tex("weak_wall")
				if wt != null:
					draw_texture_rect(wt, r, false)
				else:
					draw_rect(r, Color(0.45, 0.36, 0.28))
					draw_rect(r, Color(0.2, 0.15, 0.1), false, 1.0)
				var c := r.get_center()
				draw_line(r.position + Vector2(3, 4), c, Color(0.15, 0.1, 0.08, 0.6), 1.5)
				draw_line(c, c + Vector2(tile * 0.3, tile * 0.25), Color(0.15, 0.1, 0.08, 0.6), 1.5)
				draw_line(c, c + Vector2(-tile * 0.3, -tile * 0.2), Color(0.15, 0.1, 0.08, 0.6), 1.5)
			if state.swap_cells.has(pos):
				var st2 := tex("dark_tile")
				if st2 != null:
					draw_texture_rect(st2, r, false)
				var c := r.get_center()
				draw_circle(c, tile * 0.3, Color(0.25, 0.5, 0.9, 0.25))
				draw_arc(c, tile * 0.3, 0, TAU, 20, Color(0.4, 0.65, 1.0), 2.0)
				draw_line(c + Vector2(-tile * 0.2, -tile * 0.08), c + Vector2(tile * 0.2, -tile * 0.08), Color(0.6, 0.8, 1.0), 2.0)
				draw_line(c + Vector2(tile * 0.2, -tile * 0.08), c + Vector2(tile * 0.1, -tile * 0.2), Color(0.6, 0.8, 1.0), 2.0)
				draw_line(c + Vector2(-tile * 0.2, tile * 0.08), c + Vector2(tile * 0.2, tile * 0.08), Color(0.6, 0.8, 1.0), 2.0)
				draw_line(c + Vector2(-tile * 0.2, tile * 0.08), c + Vector2(-tile * 0.1, tile * 0.2), Color(0.6, 0.8, 1.0), 2.0)
			if state.filters.has(pos):
				var c := r.get_center()
				var fi := int(state.filters[pos])
				var pal: Array = GOAL_COLORS_CB if _cb else GOAL_COLORS
				var fcol: Color = pal[fi] if fi < pal.size() else COL_GOAL
				var ft := tex("filter")
				if ft != null:
					draw_texture_rect(ft, r, false, fcol)
				else:
					draw_rect(r, Color(fcol, 0.3))
					draw_rect(r, fcol, false, 2.0)
				_glyph(font, "BCD"[fi - 1], r, Color.WHITE, fs)
			if state.pit_cells.has(pos):
				var c := r.get_center()
				draw_rect(r, Color(0.06, 0.06, 0.1))
				draw_circle(c, tile * 0.3, Color(0.1, 0.1, 0.16))
				draw_circle(c, tile * 0.3, Color(0.35, 0.5, 0.8, 0.6), false, 1.5)
				_glyph(font, "u", r, Color(0.5, 0.65, 0.9, 0.7), fs)
			if state.pull_cells.has(pos):
				var c := r.get_center()
				draw_rect(r, Color(0.35, 0.3, 0.5, 0.3))
				draw_rect(r, Color(0.6, 0.5, 0.85, 0.7), false, 1.5)
				_glyph(font, "⇤⇥", r, Color(0.75, 0.65, 1.0), int(tile * 0.3))
			if state.switches.has(pos):
				var c := r.get_center()
				var col := COL_SWITCH_ON if state.rules_enabled else COL_SWITCH_OFF
				draw_circle(c, tile * 0.3, col.darkened(0.55))
				draw_circle(c, tile * 0.18, col)
				_glyph(font, "!", r, Color(1, 1, 1, 0.8), fs)
			if state.portal_kinds.has(pos):
				var c := r.get_center()
				var pcol := Color(0.35, 0.85, 0.95) if state.portal_kinds[pos] == "o" else Color(0.9, 0.45, 0.85)
				draw_arc(c, tile * 0.34, 0, TAU, 24, pcol, 3.0)
				draw_circle(c, tile * 0.11, pcol)
			if state.conveyors.has(pos):
				var c := r.get_center()
				var dv := Vector2(state.conveyors[pos])
				var s := Vector2(-dv.y, dv.x) * tile * 0.22
				var tip := c + dv * tile * 0.34
				var base := c - dv * tile * 0.12
				draw_colored_polygon(PackedVector2Array([tip, base + s, base - s]), Color(0.3, 0.7, 0.85, 0.75))
				var tip2 := c + dv * tile * 0.1
				var base2 := c - dv * tile * 0.36
				draw_colored_polygon(PackedVector2Array([tip2, base2 + s, base2 - s]), Color(0.3, 0.7, 0.85, 0.4))
			if show_dead and _dead.has(pos) and not state.goals.has(pos):
				# alpha 0.10 era imperceptible incluso en captura — la
				# asistencia no se veía
				draw_rect(r, Color(0.6, 0.15, 0.15, 0.22))
	if not trail_cells.is_empty():
		for tc in trail_cells.keys():
			var tcc := Vector2(tc) * tile + Vector2(tile / 2, tile / 2)
			# alpha 0.16 / r 0.09 era casi invisible en captura — la
			# "mejor ruta" no se distinguía del fondo
			draw_circle(tcc, tile * 0.12, Color(0.75, 0.75, 0.95, 0.30))
	for i in state.boxes.size():
		var bv := _pos_for(i, Vector2(state.boxes[i]))
		var r := Rect2(bv.x * tile + 3, bv.y * tile + 3, tile - 6, tile - 6)
		# drop shadow — cheap depth cue, keeps entities lifted off the floor
		draw_circle(r.get_center() + Vector2(0, tile * 0.28), tile * 0.28, Color(0, 0, 0, 0.22))
		var bpal: Array = BOX_COLORS_CB if _cb else BOX_COLORS
		var bcol_i := int(state.box_colors[i]) if i < state.box_colors.size() else 0
		var col := COL_BOX_ON_GOAL if state.goals.has(state.boxes[i]) else COL_BOX
		if _cb and col == COL_BOX_ON_GOAL:
			col = GOAL_COLORS_CB[0].lightened(0.3)
		if bcol_i > 0 and bcol_i < bpal.size():
			col = bpal[bcol_i]
			if state.goals.has(state.boxes[i]) \
					and int(state.goal_colors.get(state.boxes[i], 0)) == bcol_i:
				col = col.lightened(0.25)
		var squashed := i == _squash_i and _squash_t < 1.0
		if squashed:
			var amt := 0.22 * sin(_squash_t * PI)
			var sc := Vector2(1.0 - amt, 1.0 + amt) if absi(_squash_d.x) > 0 else Vector2(1.0 + amt, 1.0 - amt)
			draw_set_transform(r.get_center(), 0.0, sc)
		var rr := r if not squashed else Rect2(-r.size / 2, r.size)
		var on_goal: bool = state.goals.has(state.boxes[i])
		var btex: Texture2D = null
		if bcol_i > 0:
			btex = tex("box_" + "bcd"[bcol_i - 1])
		elif on_goal:
			btex = tex("box_on_goal")
		else:
			btex = tex("box")
		if btex != null:
			draw_texture_rect(btex, rr, false)
			draw_rect(rr, col.lightened(0.15), false, 1.0)
		else:
			draw_rect(rr, col)
			draw_rect(rr, col.darkened(0.35), false, 2.0)
		if squashed:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if i < state.box_mimic.size() and state.box_mimic[i]:
			draw_rect(r.grow(-4), COL_MIMIC, false, 2.5)
		if i < state.box_roll.size() and state.box_roll[i]:
			# rolling box: wheel dots under the crate
			var bc := r.get_center()
			draw_circle(bc + Vector2(-tile * 0.22, tile * 0.34), tile * 0.08,
				Color(0.15, 0.15, 0.2))
			draw_circle(bc + Vector2(tile * 0.22, tile * 0.34), tile * 0.08,
				Color(0.15, 0.15, 0.2))
		if i < state.box_heavy.size() and state.box_heavy[i]:
			var resting := i < state.box_rest.size() and state.box_rest[i] > 0
			_glyph(font, "kg", r,
				Color(0.4, 0.25, 0.15) if resting else Color(1, 1, 1, 0.9),
				int(tile * 0.32))
		if bcol_i > 0 and bcol_i < bpal.size():
			_glyph(font, "bcd"[bcol_i - 1].to_upper(), r, Color(1, 1, 1, 0.85), int(tile * 0.4))
		# ✓ on a solved box — a non-color success signal (colorblind-safe)
		if state.goals.has(state.boxes[i]) and (bcol_i == 0 \
				or int(state.goal_colors.get(state.boxes[i], 0)) == bcol_i):
			_glyph(font, "✓", r.grow(-2), Color(0, 0, 0, 0.55), int(tile * 0.38))
		if show_dead and _dead.has(state.boxes[i]) and not state.goals.has(state.boxes[i]):
			_glyph(font, "✕", r, Color(0.9, 0.25, 0.25), int(tile * 0.5))
		if state.rules_enabled:
			for rule in state.rules:
				if rule is PushLimitRule:
					var left: int = rule.pushes_left(state, i)
					_glyph(font, str(left), r, Color.RED if left <= 0 else Color.WHITE, int(tile * 0.45))
	if state.ghost_active:
		var gv := _pos_for("ghost", Vector2(state.ghost_pos))
		var gc: Vector2 = gv * tile + Vector2(tile / 2, tile / 2)
		draw_circle(gc, tile * 0.3, COL_GHOST)
		_glyph(font, "G", Rect2(gc - Vector2(tile, tile) / 2, Vector2(tile, tile)), Color(1, 1, 1, 0.5), fs)
	for ti in state.twins.size():
		# Multiban: inactive partners, dimmed and numbered.
		var tv := Vector2(state.twins[ti]) * tile
		var tc := tv + Vector2(tile / 2, tile / 2)
		draw_circle(tc + Vector2(0, tile * 0.3), tile * 0.26, Color(0, 0, 0, 0.25))
		var ttex := tex("twin")
		if ttex != null:
			draw_texture_rect(ttex, Rect2(tv.x + 1, tv.y + 1, tile - 2, tile - 2),
				false, Color(0.65, 0.65, 0.85))  # inactive: blue-dimmed
		else:
			var tw_col := COL_PLAYER2 if not _cb else Color(0.9, 0.45, 0.6)
			draw_circle(tc, tile * 0.3, tw_col.darkened(0.25))
			draw_circle(tc, tile * 0.3, Color.BLACK, false, 2.0)
		_glyph(font, str(ti + 2), Rect2(tv, Vector2(tile, tile)), Color(1, 1, 1, 0.8), fs)
	var pv := _pos_for("player", Vector2(state.player))
	var pc: Vector2 = pv * tile + Vector2(tile / 2, tile / 2)
	var pcol := COL_PLAYER
	for rule in state.rules:
		if rule is TwoPlayersRule and rule.active_player(state) == 1:
			pcol = COL_PLAYER2
	if _cb:
		pcol = Color(0.34, 0.65, 0.95)
	draw_circle(pc + Vector2(0, tile * 0.3), tile * 0.26, Color(0, 0, 0, 0.25))
	var ptex := tex("player")
	if ptex != null:
		# sprite already carries a face — no procedural eyes needed
		var pr := Rect2(pv.x * tile + 1, pv.y * tile + 1, tile - 2, tile - 2)
		draw_texture_rect(ptex, pr, false)
	else:
		draw_circle(pc, tile * 0.3, pcol)
		draw_circle(pc, tile * 0.3, Color.BLACK, false, 2.0)
		# eyes: face the last move direction so the avatar reads instantly
		var fwd := Vector2(_last_dir) * tile * 0.1
		var side := Vector2(-_last_dir.y, _last_dir.x) * tile * 0.13
		draw_circle(pc + fwd + side, tile * 0.055, Color(0.08, 0.08, 0.1))
		draw_circle(pc + fwd - side, tile * 0.055, Color(0.08, 0.08, 0.1))
	if hint_dir != Vector2i.ZERO:
		_draw_hint_arrow(pc, Vector2(hint_dir))
	for f in _flashes:
		if float(f["t"]) < 0.0:
			continue  # staggered (win cascade): not started yet
		var fp: Vector2i = f["pos"]
		var fr := Rect2(fp.x * tile, fp.y * tile, tile, tile)
		var a: float = 1.0 - float(f["t"]) / 0.35
		var fcol: Color = f.get("col", COL_FLASH)
		draw_circle(fr.get_center(), tile * (0.5 - a * 0.2), Color(fcol, fcol.a * a))
	# push dust: expanding ring + a couple of debris dots
	for p in _puffs:
		var pp: Vector2i = p["pos"]
		var c := Vector2(pp) * tile + Vector2(tile, tile) / 2
		var a2: float = 1.0 - float(p["t"]) / 0.3
		if p.get("goal", false):
			# box landed on goal: gold ring pulse, not dust
			draw_arc(c, tile * (0.1 + 0.55 * (1.0 - a2)), 0, TAU, 20,
				Color(0.95, 0.85, 0.3, 0.7 * a2), 3.0)
		else:
			draw_arc(c, tile * (0.2 + 0.3 * (1.0 - a2)), 0, TAU, 16,
				Color(0.7, 0.65, 0.55, 0.35 * a2), 2.0)


func _draw_hint_arrow(center: Vector2, dir: Vector2) -> void:
	var tip := center + dir * tile * 0.55
	var side := Vector2(-dir.y, dir.x) * tile * 0.18
	var base := center + dir * tile * 0.15
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), COL_HINT)


func _glyph(font: Font, ch: String, r: Rect2, col: Color, size: int) -> void:
	if size <= 0:
		return  # thumbnails render tiles too small for text
	var ts := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	draw_string(font, r.get_center() - Vector2(ts.x / 2, -ts.y / 4), ch,
		HORIZONTAL_ALIGNMENT_CENTER, -1, size, col)
