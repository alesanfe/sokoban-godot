class_name MapScreen
extends Control
## Navigable overworld (Isles of Sea and Sky style): an avatar walks
## between level nodes scattered over islands. Enter = play the node
## under you. Esc = menu. Clicking a node jumps there and enters it.

const T := 30.0
const MW := 64
const MH := 36

var host: Control
var land: Dictionary = {}      # Vector2i -> true
var nodes: Array = []          # [{cell: Vector2i, level: LevelData}]
var node_at: Dictionary = {}   # Vector2i -> index into nodes
var avatar := Vector2i(4, 5)
var _custom_overflow := 0      # niveles propios que no caben en la isla
var _keys := {}                # user-rebound keys (same as the game)


func _init(p_host: Control) -> void:
	host = p_host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for a in ControlsScreen.DEFAULTS.keys():
		_keys[a] = int(Storage.get_setting("key_" + a,
			ControlsScreen.DEFAULTS[a]))
	_build_map()
	_spawn_avatar()
	resized.connect(queue_redraw)  # camera/bottom bar depend on size


func _carve(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			land[Vector2i(x, y)] = true


func _add_node(cell: Vector2i, level: LevelData) -> void:
	land[cell] = true
	node_at[cell] = nodes.size()
	nodes.append({"cell": cell, "level": level})


func _build_map() -> void:
	# campaign island: serpentine path of nodes
	_carve(Rect2i(2, 3, 24, 29))
	var camp := Campaign.levels()
	for i in camp.size():
		var row := i / 8
		var col: int = i % 8
		if row % 2 == 1:
			col = 7 - col
		_add_node(Vector2i(4 + col * 3, 5 + row * 4), camp[i])
	# bridge to the big islands
	_carve(Rect2i(26, 17, 18, 2))
	# classics island
	_carve(Rect2i(44, 2, 19, 13))
	var classics := LevelPack.load_microban()
	for i in classics.size():
		_add_node(Vector2i(45 + i % 16, 4 + i / 16), classics[i])
	# custom levels island — 16×10 celdas caben; el resto se queda
	# fuera del mapa y se anuncia en el pie (antes caían en casillas
	# inalcanzables: la cámara nunca llega más allá de MH)
	_carve(Rect2i(44, 20, 19, 13))
	var customs := Storage.custom_levels()
	const CUSTOM_CAP := 16 * 10
	for i in mini(customs.size(), CUSTOM_CAP):
		_add_node(Vector2i(45 + i % 16, 22 + i / 16), customs[i])
	_custom_overflow = maxi(0, customs.size() - CUSTOM_CAP)


func _spawn_avatar() -> void:
	var camp := Campaign.levels()
	for i in camp.size():
		if Storage.best_moves(camp[i]) <= 0:
			avatar = nodes[i]["cell"]
			return


func _cam() -> Vector2:
	var px := Vector2(avatar) * T + Vector2(T, T) / 2
	var off := px - size / 2
	var maxv := Vector2(MW, MH) * T - size
	return Vector2(
		clampf(off.x, 0.0, maxf(0.0, maxv.x)),
		clampf(off.y, 0.0, maxf(0.0, maxv.y))
	)


func _step(d: Vector2i) -> void:
	var n := avatar + d
	if land.has(n):
		avatar = n
		queue_redraw()


func _enter_node() -> void:
	if node_at.has(avatar):
		host.show_game(nodes[node_at[avatar]]["level"], {"from_map": true})


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	var kc: int = e.keycode
	if kc == KEY_ESCAPE:
		host.show_menu()
	elif kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_SPACE:
		_enter_node()
	elif kc == _keys["left"] or kc == KEY_LEFT:
		_step(Vector2i(-1, 0))
	elif kc == _keys["right"] or kc == KEY_RIGHT:
		_step(Vector2i(1, 0))
	elif kc == _keys["up"] or kc == KEY_UP:
		_step(Vector2i(0, -1))
	elif kc == _keys["down"] or kc == KEY_DOWN:
		_step(Vector2i(0, 1))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i((e.position + _cam()) / T)
		if node_at.has(cell):
			avatar = cell
			_enter_node()


func _draw() -> void:
	var cam := _cam()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.14))
	for c in land.keys():
		var r := Rect2(Vector2(c) * T - cam, Vector2(T, T))
		draw_rect(r, Color(0.13, 0.16, 0.13))
		draw_rect(r, Color(1, 1, 1, 0.04), false, 1.0)
	_text(font, "CAMPAÑA MUTANTE", Vector2(4.0, 4.2) * T - cam, 18, Color(0.95, 0.8, 0.2, 0.85))
	_text(font, "CLÁSICOS", Vector2(45.0, 3.2) * T - cam, 18, Color(0.4, 0.8, 0.9, 0.85))
	_text(font, "MIS NIVELES" + ("  (+%d más)" % _custom_overflow
		if _custom_overflow > 0 else ""),
		Vector2(45.0, 21.2) * T - cam, 18, Color(0.9, 0.7, 0.3, 0.85))
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var c: Vector2i = nd["cell"]
		var ctr := Vector2(c) * T - cam + Vector2(T / 2, T / 2)
		var level: LevelData = nd["level"]
		var best := Storage.best_moves(level)
		var col := Color(0.5, 0.5, 0.56)
		if best > 0:
			col = Color(0.95, 0.8, 0.2) if level.par > 0 and best <= level.par else Color(0.3, 0.85, 0.5)
		draw_circle(ctr, T * 0.3, col)
		draw_circle(ctr, T * 0.3, col.darkened(0.5), false, 1.5)
		if c == avatar:
			draw_arc(ctr, T * 0.44, 0, TAU, 24, Color.WHITE, 2.5)
	var ac := Vector2(avatar) * T - cam + Vector2(T / 2, T / 2)
	draw_circle(ac, T * 0.24, Color(0.95, 0.8, 0.2))
	draw_circle(ac, T * 0.24, Color.BLACK, false, 2.0)
	# bottom bar
	draw_rect(Rect2(0, size.y - 38, size.x, 38), Color(0.05, 0.05, 0.08, 0.88))
	var text := "Mapa del mundo — Flechas/WASD mover · Enter jugar · Esc menú"
	if node_at.has(avatar):
		var level: LevelData = nodes[node_at[avatar]]["level"]
		text = "%s%s — Enter para jugar" % [level.title, Widgets.stars(level.difficulty)]
	draw_string(font, Vector2(16, size.y - 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _text(font: Font, s: String, pos: Vector2, size_px: int, col: Color) -> void:
	draw_string(font, pos + Vector2(0, size_px), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
