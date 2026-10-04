class_name LevelSelectScreen
extends Control
## Campaign + custom level picker with mini-board thumbnails.


class LevelThumb extends Control:
	var board: PackedStringArray
	var over := {}  # overlays de ocupante (LevelData.over), opcional
	var cb := false  # paleta Okabe–Ito cuando el tema es Daltonismo

	func _init(p_board: PackedStringArray, p_over: Dictionary = {}) -> void:
		board = p_board
		over = p_over
		cb = UiTheme.current_mode() == "cb"

	# paletas de cajas/metas respetando el tema Daltonismo
	func bx_col() -> Array:
		return BoardView.BOX_COLORS_CB if cb else BoardView.BOX_COLORS

	func gl_col() -> Array:
		return BoardView.GOAL_COLORS_CB if cb else BoardView.GOAL_COLORS
		custom_minimum_size = Vector2(76, 42)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := 1
		var h := board.size()
		for ln in board:
			w = maxi(w, ln.length())
		var t := minf(size.x / w, size.y / h)
		var ox := (size.x - w * t) / 2.0
		var oy := (size.y - h * t) / 2.0
		# fondo del thumbnail con el panel del tema (en Claro quedaba
		# un parche negro dentro de una lista clara)
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.bg_color())
		for y in h:
			for x in w:
				var ch: String = board[y][x] if x < board[y].length() else " "
				var r := Rect2(ox + x * t, oy + y * t, t, t)
				var arrow := func(dir: Vector2, col: Color) -> void:
					var c := r.get_center()
					var a := dir * t * 0.45
					var s := Vector2(-dir.y, dir.x) * t * 0.3
					draw_colored_polygon(PackedVector2Array(
						[c + a, c - a + s, c - a - s]), col)
				match ch:
					"#":
						draw_rect(r, UiTheme.dim())
					"?":
						draw_rect(r, Color(0.55, 0.4, 0.6))
					"W":
						draw_rect(r, UiTheme.dim())
						draw_rect(r.grow(-t * 0.15), UiTheme.dim())
					"$", "*":
						draw_rect(r.grow(-0.5), Color(0.72, 0.5, 0.24))
					"&", "%":
						draw_rect(r.grow(-0.5), Color(0.7, 0.35, 0.85))
					"b", "c", "d":
						draw_rect(r.grow(-0.5),
							bx_col()["bcd".find(ch) + 1])
					"a", "e", "i", "j", "l", "m":
						# compuestos: caja de color (sobre meta)
						draw_rect(r.grow(-0.5),
							bx_col()["aeijlm".find(ch) % 3 + 1])
					"q":
						draw_circle(r.get_center(), maxf(t * 0.35, 1.0),
							Color(0.72, 0.5, 0.24))
					"n":
						draw_rect(r.grow(-0.5), Color(0.45, 0.34, 0.2))
					".":
						draw_circle(r.get_center(), maxf(t * 0.3, 1.0), UiTheme.ok())
					"B", "C", "D":
						draw_circle(r.get_center(), maxf(t * 0.28, 1.0),
							gl_col()["BCD".find(ch) + 1])
					"E", "G", "H":
						draw_rect(r, gl_col()[
							"EGH".find(ch) + 1], false, 2.0)
					"@", "+":
						draw_circle(r.get_center(), maxf(t * 0.35, 1.0), UiTheme.accent())
					"p":
						draw_circle(r.get_center(), maxf(t * 0.3, 1.0), Color(0.95, 0.6, 0.3))
					"!":
						draw_rect(r, Color(0.55, 0.4, 0.6))
					"o":
						draw_circle(r.get_center(), maxf(t * 0.3, 1.0), UiTheme.info())
					"O":
						draw_circle(r.get_center(), maxf(t * 0.3, 1.0), Color(0.9, 0.45, 0.85))
					">", "<", "^", "v":
						arrow.call({">": Vector2(1, 0), "<": Vector2(-1, 0),
							"^": Vector2(0, -1), "v": Vector2(0, 1)}[ch],
							Color(0.35, 0.6, 0.85))
					"1", "2", "3", "4":
						arrow.call({"1": Vector2(1, 0), "2": Vector2(0, 1),
							"3": Vector2(-1, 0), "4": Vector2(0, -1)}[ch],
							Color(0.75, 0.65, 1.0))
					"k":
						draw_circle(r.get_center(), maxf(t * 0.2, 1.0), Color(1.0, 0.85, 0.3))
					"K":
						draw_rect(r, Color(0.5, 0.35, 0.1))
					"x":
						draw_circle(r.get_center(), maxf(t * 0.3, 1.0), Color(0.75, 0.25, 0.2))
					"h", "u":
						draw_circle(r.get_center(), maxf(t * 0.3, 1.0), Color(0.02, 0.02, 0.04))
					"f":
						draw_rect(r, Color(0.55, 0.45, 0.35))
					"w":
						draw_rect(r, Color(0.9, 0.5, 0.7), false, 2.0)
					"z":
						draw_rect(r, Color(0.3, 0.55, 0.45), false, 2.0)
					"=":
						draw_rect(Rect2(r.position.x, r.get_center().y - t * 0.12,
							t, maxf(t * 0.08, 1.0)), UiTheme.dim())
						draw_rect(Rect2(r.position.x, r.get_center().y + t * 0.08,
							t, maxf(t * 0.08, 1.0)), UiTheme.dim())
					":":
						draw_rect(Rect2(r.get_center().x - t * 0.12, r.position.y,
							maxf(t * 0.08, 1.0), t), UiTheme.dim())
						draw_rect(Rect2(r.get_center().x + t * 0.08, r.position.y,
							maxf(t * 0.08, 1.0), t), UiTheme.dim())
		# overlays de ocupante por encima del terreno
		for op in over.keys():
			var os: Dictionary = over[op]
			var orr := Rect2(ox + op.x * t, oy + op.y * t, t, t)
			var oc := int(os.get("c", 0))
			draw_rect(orr.grow(-0.5),
				bx_col()[oc] if oc > 0 else Color(0.72, 0.5, 0.24))


var _list: VBoxContainer
var _scroll: ScrollContainer
var _filter_edit: LineEdit
var _next_unsolved: Control = null

# Contexto al volver («volver conserva la navegación»): el filtro y
# el scroll sobreviven a ida/vuelta jugar↔selector dentro de la sesión
static var _saved_filter := ""
static var _saved_scroll := 0


func _init(host: Control) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var top := HBoxContainer.new()
	var back := Widgets.button("← Menú")
	back.custom_minimum_size.x = 140
	back.pressed.connect(host.show_menu)
	top.add_child(back)
	top.add_child(Widgets.label("  Elige un nivel", 26))
	_stats = Widgets.label("", 15, UiTheme.ok())
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_stats)
	v.add_child(top)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "Buscar por título o regla…"
	_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_edit.text = _saved_filter
	_filter_edit.text_changed.connect(func(_t):
		_saved_filter = _t
		_saved_scroll = 0
		_populate(host))
	bar.add_child(_filter_edit)
	# foco inicial en el buscador: primer gesto natural al elegir nivel
	Widgets.deferred(_filter_edit,
		func(): _filter_edit.grab_focus())
	var b_next := Widgets.primary("▶ Siguiente sin resolver")
	b_next.pressed.connect(func():
		if _next_unsolved:
			_scroll.scroll_vertical = int(_next_unsolved.position.y) - 60)
	bar.add_child(b_next)
	v.add_child(bar)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	# guarda el scroll al salir (el swap destruye el screen)
	_scroll.get_v_scroll_bar().value_changed.connect(func(v2: float):
		_saved_scroll = int(v2))
	_populate(host)
	Widgets.deferred(self,
		func(): _scroll.scroll_vertical = _saved_scroll)


var _stats: Label


func _populate(host: Control) -> void:
	for c in _list.get_children():
		c.queue_free()
	_next_unsolved = null
	_refresh_totals()
	var f := _filter_edit.text.strip_edges().to_lower()

	var matches := func(level: LevelData) -> bool:
		if f == "":
			return true
		if level.title.to_lower().contains(f):
			return true
		for r in level.rules:
			var d := RuleRegistry.describe(r.get("id", ""))
			if str(d.get("title", "")).to_lower().contains(f) or str(r.get("id", "")).contains(f):
				return true
		return false

	var added := 0
	var add_section := func(levels: Array, heading: String, col: Color, sub: String = "") -> void:
		var shown: Array = []
		for level in levels:
			if matches.call(level):
				shown.append(level)
		if shown.is_empty() and f != "":
			return
		_list.add_child(Widgets.label(heading, 22, col))
		if sub != "":
			_list.add_child(Widgets.label(sub, 14, UiTheme.dim()))
		for level in shown:
			var row := _level_button(host, level, heading == "Mis niveles")
			_list.add_child(row)
			added += 1
			if _next_unsolved == null and Storage.best_moves(level) <= 0:
				_next_unsolved = row

	var classics := LevelPack.load_microban()
	var done := 0
	for level in classics:
		if Storage.best_moves(level) > 0:
			done += 1
	add_section.call(Campaign.levels(), "Campaña Mutante", UiTheme.accent())
	_list.add_child(Widgets.hsep())
	add_section.call(classics, "Clásicos · Microban (David W. Skinner)",
		UiTheme.info(), "  %d niveles — %d completados" % [classics.size(), done])
	_list.add_child(Widgets.hsep())
	var customs := Storage.custom_levels()
	add_section.call(customs, "Mis niveles", UiTheme.accent())
	if customs.is_empty():
		_list.add_child(Widgets.label("  (vacío — crea niveles en el editor o importa un código)", 14, UiTheme.dim()))
	else:
		var b_pack := Widgets.button("Exportar colección (código de pack)")
		b_pack.pressed.connect(func():
			var code := LevelData.pack_code(customs)
			DisplayServer.clipboard_set(code)
			b_pack.text = "✓ Pack copiado al portapapeles (%d niveles)" % customs.size()
		)
		_list.add_child(b_pack)
	# estado «sin resultados»: sin él el filtro dejaba una lista
	# vacía que parecía un bug
	if added == 0 and f != "":
		_list.add_child(Widgets.label(
			"  Sin niveles que coincidan con «%s»." % _filter_edit.text,
			15, UiTheme.dim()))


func _stars_for(level: LevelData, best: int) -> int:
	if level.par <= 0:
		return 1
	if best <= level.par:
		return 3
	if best <= int(level.par * 1.5):
		return 2
	return 1


func _refresh_totals() -> void:
	var done := 0
	var stars := 0
	var all: Array = []
	all.append_array(Campaign.levels())
	all.append_array(LevelPack.load_microban())
	all.append_array(Storage.custom_levels())
	for l in all:
		var bm := Storage.best_moves(l)
		if bm > 0:
			done += 1
			stars += _stars_for(l, bm)
	_stats.text = "%d/%d niveles · %d★" % [done, all.size(), stars]


func _level_button(host: Control, level: LevelData, deletable: bool = false) -> Control:
	var best := Storage.best_moves(level)
	var label := ("✓ " if best > 0 else "· ") + level.title + Widgets.stars(level.difficulty)
	if best > 0:
		label += " " + "★".repeat(_stars_for(level, best))
	if level.par > 0:
		label += "  ·  par: %d" % level.par
	if best > 0:
		label += "  ·  mejor: %d" % best
	if not level.rules.is_empty():
		var names := PackedStringArray()
		for r in level.rules:
			names.append(str(RuleRegistry.describe(r.get("id", "")).get("title", r.get("id", ""))))
		label += "  ·  " + ", ".join(names)
	elif level.has_peekaboo():
		label += "  ·  Paredes tímidas"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(LevelThumb.new(level.board, level.over))
	var b := Widgets.button(label)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): host.show_game(level))
	row.add_child(b)
	if deletable:
		var b_del := Widgets.button("✕")
		b_del.tooltip_text = "Borrar este nivel (clic dos veces)"
		var armed := false
		b_del.pressed.connect(func():
			if not armed:
				armed = true
				b_del.text = "¿?"
				Widgets.set_danger(b_del, true)
				Widgets.toast(self, "⚠ Pulsa de nuevo para borrar")
				get_tree().create_timer(2.0).timeout.connect(func():
					armed = false
					if is_instance_valid(b_del):
						b_del.text = "✕"
						Widgets.set_danger(b_del, false))
				return
			Storage.delete_custom_level(level)
			_populate(host))
		row.add_child(b_del)
	return row
