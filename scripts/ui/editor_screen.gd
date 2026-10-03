class_name EditorScreen
extends Control
## Level editor: paint tiles, attach rules with params, playtest,
## verify with the solver, save and export share codes.

const TOOLS := [
	["Borrar/Suelo", " "],
	["Pared", "#"],
	["Pared tímida (?)", "?"],
	["Interruptor (!)", "!"],
	["Caja", "$"],
	["Caja mimética (&)", "&"],
	["Objetivo", "."],
	["Jugador", "@"],
	["Portal A (o)", "o"],
	["Portal B (O)", "O"],
	["Cinta →", ">"],
	["Cinta ←", "<"],
	["Cinta ↑", "^"],
	["Cinta ↓", "v"],
]
const TOOLS2 := [
	["Llave", "k"],
	["Puerta", "K"],
	["Bomba", "x"],
	["Solo →", "1"],
	["Solo ↓", "2"],
	["Solo ←", "3"],
	["Solo ↑", "4"],
	["Caja B", "b"],
	["Caja C", "c"],
	["Caja D", "d"],
	["Meta B", "B"],
	["Meta C", "C"],
	["Meta D", "D"],
]
const TOOLS3 := [
	["Agujero (h)", "h"],
	["Suelo frágil (f)", "f"],
	["Raíl H (=)", "="],
	["Raíl V (:)", ":"],
	["Muro débil (W)", "W"],
	["Intercambio (w)", "w"],
	["Gemelo (p)", "p"],
	["Filtro B (E)", "E"],
	["Filtro C (G)", "G"],
	["Filtro D (H)", "H"],
]
const TOOLS4 := [
	["Caja rodante (q)", "q"],
	["Caja pesada (n)", "n"],
	["Sumidero (u)", "u"],
	["Tracción (z)", "z"],
]
const TOOLS5 := [
	["B en meta B (a)", "a"],
	["C en meta C (e)", "e"],
	["D en meta D (i)", "i"],
	["B en meta (j)", "j"],
	["C en meta (l)", "l"],
	["D en meta (m)", "m"],
]

var host: Control
var grid_w := 12
var grid_h := 9
var cells := {}          # Vector2i -> char
var over := {}           # Vector2i -> {c,m,r,h} caja sobre terreno
# no componible (LevelData.over)
var tool := "#"
var _tool_buttons := {}      # tool id -> palette Button (eyedrop sync)
var rule_entries: Array = []  # [{id, controls:{key->Control}}]
var editing: LevelData = null # level being edited (to keep title/etc.)

# editor QoL: undo/redo, shape tools, symmetry, dead-square overlay
var shape := "point"                # point | line | rect | fill
var drag_anchor := Vector2i(-1, -1) # first cell of a line/rect stroke
var mirror_x := false
var mirror_y := false
var show_dead := false
var _dead: Dictionary = {}
var _undo_stack: Array = []
var _redo_stack: Array = []
var _solution := PackedStringArray()
var b_play_sol: Button
var _dirty := false          # ediciones sin guardar (aviso al salir)

var grid: EditorGrid
var title_edit: LineEdit
var author_edit: LineEdit
var status: Label
var code_edit: LineEdit
var rules_box: VBoxContainer
var rules_panel: EditorRulesPanel
var w_spin: SpinBox
var h_spin: SpinBox
var hidden_check: CheckBox


class EditorGrid extends Control:
	var editor: EditorScreen
	var tile := 40.0
	var hover := Vector2i(-1, -1)
	var painting := false
	var erasing := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func cell_at(p: Vector2) -> Vector2i:
		return Vector2i(int(p.x / tile), int(p.y / tile))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_MIDDLE and e.pressed:
				editor._eyedrop(cell_at(e.position))
				return
			if e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					if e.alt_pressed:
						editor._eyedrop(cell_at(e.position))
						return
					if editor.shape in ["line", "rect"]:
						editor.drag_anchor = cell_at(e.position)
					else:
						painting = true
						editor.begin_stroke()
						editor.paint_cell(cell_at(e.position), false)
				else:
					painting = false
					if editor.drag_anchor != Vector2i(-1, -1):
						editor.commit_shape(cell_at(e.position))
						editor.drag_anchor = Vector2i(-1, -1)
						queue_redraw()
					else:
						editor._refresh_dead()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				erasing = e.pressed
				if erasing:
					editor.begin_stroke()
					editor.paint_cell(cell_at(e.position), true)
				else:
					editor._refresh_dead()
		elif e is InputEventMouseMotion:
			hover = cell_at(e.position)
			if painting:
				editor.paint_cell(hover, false)
			elif erasing:
				editor.paint_cell(hover, true)
			queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		# colorblind theme → Okabe–Ito palettes (same as BoardView)
		var cb := UiTheme.current_mode() == "cb"
		var bpal: Array = BoardView.BOX_COLORS_CB if cb else BoardView.BOX_COLORS
		var gpal: Array = BoardView.GOAL_COLORS_CB if cb else BoardView.GOAL_COLORS
		for y in editor.grid_h:
			for x in editor.grid_w:
				var pos := Vector2i(x, y)
				var r := Rect2(x * tile, y * tile, tile, tile)
				draw_rect(r, Color(0.13, 0.14, 0.17))
				draw_rect(r, Color(1, 1, 1, 0.08), false, 1.0)
				var ch: String = editor.cells.get(pos, "")
				match ch:
					"#":
						draw_rect(r, Color(0.36, 0.38, 0.45))
					"?":
						draw_rect(r, Color(0.55, 0.4, 0.6, 0.5))
						_text(font, "?", r, Color.WHITE)
					"!":
						draw_rect(r, Color(0.13, 0.14, 0.17))
						draw_circle(r.get_center(), tile * 0.28, Color(0.85, 0.35, 0.35))
						_text(font, "!", r, Color.WHITE)
					"$", "*":
						draw_circle(r.get_center(), tile * 0.18, Color(0.25, 0.7, 0.35))
						draw_rect(r.grow(-3), Color(0.72, 0.5, 0.24))
					"&", "%":
						draw_rect(r.grow(-3), Color(0.7, 0.35, 0.85))
						_text(font, "&", r, Color.WHITE)
					".":
						draw_circle(r.get_center(), tile * 0.18, Color(0.25, 0.7, 0.35))
					"@", "+":
						draw_circle(r.get_center(), tile * 0.28, Color(0.95, 0.8, 0.2))
					"o", "O":
						var pc := Color(0.35, 0.85, 0.95) if ch == "o" else Color(0.9, 0.45, 0.85)
						draw_arc(r.get_center(), tile * 0.3, 0, TAU, 20, pc, 2.5)
						_text(font, ch, r, pc)
					">", "<", "^", "v":
						var dd: Vector2 = {">": Vector2(1, 0), "<": Vector2(-1, 0), "^": Vector2(0, -1), "v": Vector2(0, 1)}[ch]
						var c := r.get_center()
						var tip := c + dd * tile * 0.32
						var s := Vector2(-dd.y, dd.x) * tile * 0.2
						var base := c - dd * tile * 0.14
						draw_colored_polygon(PackedVector2Array([tip, base + s, base - s]), Color(0.3, 0.7, 0.85))
					"k":
						_text(font, "k", r, Color(0.95, 0.85, 0.3))
					"K":
						draw_rect(r.grow(-2), Color(0.5, 0.32, 0.2))
						_text(font, "K", r, Color(0.95, 0.85, 0.3))
					"x":
						draw_circle(r.get_center(), tile * 0.26, Color(0.16, 0.16, 0.18))
						draw_circle(r.get_center(), tile * 0.26, Color(0.95, 0.4, 0.2), false, 2.0)
					"1", "2", "3", "4":
						var dw: Vector2 = {"1": Vector2(1, 0), "2": Vector2(0, 1), "3": Vector2(-1, 0), "4": Vector2(0, -1)}[ch]
						var c := r.get_center()
						var sw := Vector2(-dw.y, dw.x) * tile * 0.2
						draw_colored_polygon(PackedVector2Array(
							[c + dw * tile * 0.34, c - dw * tile * 0.1 + sw, c - dw * tile * 0.1 - sw]),
							Color(0.8, 0.6, 0.9, 0.7))
					"h":
						draw_circle(r.get_center(), tile * 0.34, Color(0.02, 0.02, 0.04))
						draw_circle(r.get_center(), tile * 0.34, Color(0.45, 0.4, 0.55, 0.7), false, 2.0)
					"f":
						var cf := r.get_center()
						draw_rect(r, Color(0.35, 0.3, 0.22, 0.35))
						draw_line(r.position + Vector2(3, 3), cf, Color(0.8, 0.75, 0.6, 0.6), 1.5)
						draw_line(cf, cf + Vector2(tile * 0.3, tile * 0.28), Color(0.8, 0.75, 0.6, 0.6), 1.5)
					"=":
						draw_line(r.get_center() + Vector2(-tile * 0.4, tile * 0.25),
							r.get_center() + Vector2(tile * 0.4, tile * 0.25), Color(0.6, 0.62, 0.7), 2.5)
						draw_line(r.get_center() + Vector2(-tile * 0.4, -tile * 0.25),
							r.get_center() + Vector2(tile * 0.4, -tile * 0.25), Color(0.6, 0.62, 0.7), 2.5)
					":":
						draw_line(r.get_center() + Vector2(tile * 0.25, -tile * 0.4),
							r.get_center() + Vector2(tile * 0.25, tile * 0.4), Color(0.6, 0.62, 0.7), 2.5)
						draw_line(r.get_center() + Vector2(-tile * 0.25, -tile * 0.4),
							r.get_center() + Vector2(-tile * 0.25, tile * 0.4), Color(0.6, 0.62, 0.7), 2.5)
					"W":
						draw_rect(r, Color(0.45, 0.36, 0.28))
						draw_rect(r, Color(0.2, 0.15, 0.1), false, 1.0)
						var cw := r.get_center()
						draw_line(r.position + Vector2(3, 4), cw, Color(0.15, 0.1, 0.08), 1.5)
						draw_line(cw, cw + Vector2(tile * 0.3, tile * 0.25), Color(0.15, 0.1, 0.08), 1.5)
					"w":
						var cs := r.get_center()
						draw_circle(cs, tile * 0.3, Color(0.25, 0.5, 0.9, 0.3))
						draw_arc(cs, tile * 0.3, 0, TAU, 20, Color(0.4, 0.65, 1.0), 2.0)
						_text(font, "w", r, Color(0.7, 0.85, 1.0))
					"p":
						draw_circle(r.get_center(), tile * 0.28, Color(0.95, 0.5, 0.15))
						_text(font, "2", r, Color(0.2, 0.1, 0.0))
					"q":
						draw_rect(r, Color(0.72, 0.5, 0.24))
						draw_rect(r, Color(0.4, 0.28, 0.14), false, 2.0)
						var cq := r.get_center()
						draw_circle(cq + Vector2(-tile * 0.2, tile * 0.3), tile * 0.08, Color(0.1, 0.1, 0.12))
						draw_circle(cq + Vector2(tile * 0.2, tile * 0.3), tile * 0.08, Color(0.1, 0.1, 0.12))
					"n":
						draw_rect(r, Color(0.5, 0.4, 0.3))
						draw_rect(r, Color(0.3, 0.22, 0.16), false, 2.0)
						_text(font, "kg", r, Color(0.9, 0.85, 0.8))
					"u":
						draw_rect(r, Color(0.08, 0.08, 0.14))
						draw_circle(r.get_center(), tile * 0.3, Color(0.12, 0.12, 0.2))
						_text(font, "u", r, Color(0.5, 0.65, 0.9))
					"z":
						draw_rect(r, Color(0.35, 0.3, 0.5, 0.5))
						_text(font, "⇤⇥", r, Color(0.75, 0.65, 1.0))
					"E", "G", "H":
						var fi := "EGH".find(ch) + 1
						draw_rect(r, gpal[fi].darkened(0.35))
						draw_rect(r, gpal[fi], false, 2.0)
						_text(font, "BCD"[fi - 1], r, Color.WHITE)
					"b", "c", "d":
						var ci := "bcd".find(ch) + 1
						draw_rect(r.grow(-3), bpal[ci])
						_text(font, ch.to_upper(), r, Color.WHITE)
					"B", "C", "D":
						var gi := "BCD".find(ch) + 1
						draw_circle(r.get_center(), tile * 0.18, gpal[gi])
						draw_arc(r.get_center(), tile * 0.28, 0, TAU, 20, gpal[gi], 2.0)
					"a", "e", "i", "j", "l", "m":
						# caja de color sobre meta (a/e/i = meta de su color)
						var ci2 := "aeijlm".find(ch) % 3 + 1
						draw_circle(r.get_center(), tile * 0.18,
							gpal[ci2] if ch in "aei" else Color(0.25, 0.7, 0.35))
						draw_rect(r.grow(-3), bpal[ci2])
						_text(font, "bcd"["aeijlm".find(ch) % 3].to_upper(), r, Color.WHITE)
		# overlays: caja posada sobre terreno no componible — se dibuja
		# encima del tile (misma iconografía que una caja normal)
		for op in editor.over.keys():
			var os: Dictionary = editor.over[op]
			var orr := Rect2(op.x * tile, op.y * tile, tile, tile)
			var oc := int(os.get("c", 0))
			draw_rect(orr.grow(-3), bpal[oc] if oc > 0 else Color(0.72, 0.5, 0.24))
			if os.get("m", false):
				_text(font, "&", orr, Color.WHITE)
			elif os.get("r", false):
				_text(font, "q", orr, Color.WHITE)
			elif os.get("h", false):
				_text(font, "kg", orr, Color(0.9, 0.85, 0.8))
			elif oc > 0:
				_text(font, "BCD"[oc - 1], orr, Color.WHITE)
		if editor.show_dead:
			for c in editor._dead.keys():
				draw_rect(Rect2(c.x * tile, c.y * tile, tile, tile), Color(0.6, 0.15, 0.15, 0.25))
		if editor.drag_anchor != Vector2i(-1, -1) and editor._cell_ok(hover):
			for c in editor._shape_cells(editor.drag_anchor, hover):
				draw_rect(Rect2(c.x * tile, c.y * tile, tile, tile), Color(0.4, 0.8, 0.9, 0.3))
		if editor._cell_ok(hover):
			draw_rect(Rect2(hover.x * tile, hover.y * tile, tile, tile), Color(1, 1, 1, 0.15))

	func _text(font: Font, ch: String, r: Rect2, col: Color) -> void:
		var size := int(tile * 0.5)
		var ts := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
		draw_string(font, r.get_center() - Vector2(ts.x / 2, -ts.y / 4), ch, HORIZONTAL_ALIGNMENT_CENTER, -1, size, col)


func _init(p_host: Control, p_level: LevelData = null) -> void:
	host = p_host
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 16)
	add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# --- left: grid
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left)
	grid = EditorGrid.new()
	grid.editor = self
	grid.custom_minimum_size = Vector2(grid_w, grid_h) * grid.tile
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(grid)

	# palette — ButtonGroup makes tool selection exclusive across rows
	var tool_group := ButtonGroup.new()
	# HFlowContainer (no HBox): cada fila hace wrap interno en vez de
	# desbordar la ventana por la derecha cuando no cabe
	var pal := HFlowContainer.new()
	pal.add_theme_constant_override("h_separation", 6)
	left.add_child(pal)
	for t in TOOLS:
		var b := Button.new()
		b.text = t[0]
		b.toggle_mode = true
		b.button_group = tool_group
		b.pressed.connect(func(): _pick_tool(t[1]))
		_tool_buttons[t[1]] = b
		pal.add_child(b)
		if t[1] == "#":
			b.button_pressed = true
	var pal2 := HFlowContainer.new()
	pal2.add_theme_constant_override("h_separation", 6)
	left.add_child(pal2)
	for t in TOOLS2:
		var b := Button.new()
		b.text = t[0]
		b.toggle_mode = true
		b.button_group = tool_group
		b.pressed.connect(func(): _pick_tool(t[1]))
		_tool_buttons[t[1]] = b
		pal2.add_child(b)
	var pal3 := HFlowContainer.new()
	pal3.add_theme_constant_override("h_separation", 6)
	left.add_child(pal3)
	for t in TOOLS3:
		var b := Button.new()
		b.text = t[0]
		b.toggle_mode = true
		b.button_group = tool_group
		b.pressed.connect(func(): _pick_tool(t[1]))
		_tool_buttons[t[1]] = b
		pal3.add_child(b)
	var pal4 := HFlowContainer.new()
	pal4.add_theme_constant_override("h_separation", 6)
	left.add_child(pal4)
	for t in TOOLS4:
		var b := Button.new()
		b.text = t[0]
		b.toggle_mode = true
		b.button_group = tool_group
		b.pressed.connect(func(): _pick_tool(t[1]))
		_tool_buttons[t[1]] = b
		pal4.add_child(b)
	var pal5 := HFlowContainer.new()
	pal5.add_theme_constant_override("h_separation", 6)
	left.add_child(pal5)
	for t in TOOLS5:
		var b := Button.new()
		b.text = t[0]
		b.toggle_mode = true
		b.button_group = tool_group
		b.pressed.connect(func(): _pick_tool(t[1]))
		_tool_buttons[t[1]] = b
		pal5.add_child(b)

	# shape modes + symmetry + board tools + clipboard
	# (flow: si no cabe hace wrap en vez de empujar el panel derecho)
	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("h_separation", 5)
	left.add_child(row2)
	for s in ["point", "line", "rect", "fill"]:
		var b := Button.new()
		b.text = {"point": "·", "line": "╱", "rect": "▭", "fill": "▩"}[s]
		b.custom_minimum_size = Vector2(32, 30)
		b.toggle_mode = true
		b.button_pressed = s == shape
		b.tooltip_text = {"point": "Punto", "line": "Línea (arrastra)",
			"rect": "Rectángulo relleno (arrastra)", "fill": "Relleno (flood)"}[s]
		b.pressed.connect(func(): shape = s)
		row2.add_child(b)
	var chk_mx := CheckBox.new()
	chk_mx.text = "Espejo X"
	chk_mx.tooltip_text = "Pinta simétrico respecto al eje vertical"
	chk_mx.pressed.connect(func(): mirror_x = chk_mx.button_pressed)
	row2.add_child(chk_mx)
	var chk_my := CheckBox.new()
	chk_my.text = "Espejo Y"
	chk_my.tooltip_text = "Pinta simétrico respecto al eje horizontal"
	chk_my.pressed.connect(func(): mirror_y = chk_my.button_pressed)
	row2.add_child(chk_my)
	for tf in [["↶", "Deshacer (Ctrl+Z)", _editor_undo],
			["↷", "Rehacer (Ctrl+Y)", _editor_redo],
			["↔", "Voltear horizontal", _flip_h], ["↕", "Voltear vertical", _flip_v],
			["⟳", "Rotar 90° horario", _rot90],
			["−", "Alejar", _zoom_out], ["+", "Acercar", _zoom_in]]:
		var b := Button.new()
		b.text = tf[0]
		b.custom_minimum_size = Vector2(32, 30)
		b.tooltip_text = tf[1]
		b.pressed.connect(tf[2])
		row2.add_child(b)
	var b_copy := Button.new()
	b_copy.text = "Copiar"
	b_copy.tooltip_text = "Copiar tablero al portapapeles (texto)"
	b_copy.pressed.connect(_copy_board)
	row2.add_child(b_copy)
	var b_paste := Button.new()
	b_paste.text = "Pegar"
	b_paste.tooltip_text = "Pegar tablero desde el portapapeles"
	b_paste.pressed.connect(_paste_board)
	row2.add_child(b_paste)
	var chk_dead := CheckBox.new()
	chk_dead.text = "Muertes"
	chk_dead.tooltip_text = "Marcar casillas donde una caja queda bloqueada (niveles clásicos)"
	chk_dead.pressed.connect(func():
		show_dead = chk_dead.button_pressed
		_refresh_dead()
		grid.queue_redraw())
	row2.add_child(chk_dead)

	# --- right panel
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 300
	side.add_theme_constant_override("separation", 8)
	hbox.add_child(side)

	side.add_child(Widgets.label("Editor de niveles", 24, Color(0.95, 0.8, 0.2)))
	title_edit = LineEdit.new()
	title_edit.placeholder_text = "Título"
	side.add_child(title_edit)
	author_edit = LineEdit.new()
	author_edit.placeholder_text = "Autor"
	side.add_child(author_edit)

	var size_row := HBoxContainer.new()
	size_row.add_child(Widgets.label("Tamaño:", 14))
	w_spin = SpinBox.new()
	w_spin.min_value = 5
	w_spin.max_value = 30
	w_spin.value = grid_w
	size_row.add_child(w_spin)
	size_row.add_child(Widgets.label("x", 14))
	h_spin = SpinBox.new()
	h_spin.min_value = 5
	h_spin.max_value = 24
	h_spin.value = grid_h
	size_row.add_child(h_spin)
	var b_size := Button.new()
	b_size.text = "Aplicar"
	b_size.pressed.connect(_resize_grid)
	size_row.add_child(b_size)
	var b_clear := Button.new()
	b_clear.text = "Limpiar"
	b_clear.pressed.connect(func(): _push_undo(); cells.clear(); over.clear(); grid.queue_redraw())
	size_row.add_child(b_clear)
	side.add_child(size_row)

	side.add_child(Widgets.hsep())
	side.add_child(Widgets.label("Reglas absurdas", 18, Color(0.7, 0.5, 0.9)))
	hidden_check = CheckBox.new()
	hidden_check.text = "Regla secreta (el jugador la descubre)"
	side.add_child(hidden_check)
	var add_row := HBoxContainer.new()
	var rule_pick := OptionButton.new()
	# sin esto su min-width = el ítem más largo (~500px) y empuja
	# el panel lateral fuera de la ventana
	rule_pick.fit_to_longest_item = false
	rule_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in RuleRegistry.all_ids():
		rule_pick.add_item(str(RuleRegistry.describe(id)["title"]) + " (" + id + ")")
	add_row.add_child(rule_pick)
	var b_add := Button.new()
	b_add.text = "Añadir"
	b_add.pressed.connect(func(): _add_rule(RuleRegistry.all_ids()[rule_pick.selected]))
	add_row.add_child(b_add)
	side.add_child(add_row)
	rules_box = VBoxContainer.new()
	rules_box.add_theme_constant_override("separation", 6)
	side.add_child(rules_box)
	# el panel posee rule_entries y pinta dentro de rules_box;
	# cada mutación invalida la solución verificada (la del tablero
	# anterior ya no reproduce este nivel)
	rules_panel = EditorRulesPanel.new(rules_box, rule_entries,
		_invalidate_solution)

	side.add_child(Widgets.hsep())
	status = Widgets.label("", 13, Color(0.7, 0.9, 0.7))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(status)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	var b_test := Widgets.primary("Probar")
	# la fila es compacta: el min-size 260×44 de la base desbordaría
	b_test.custom_minimum_size = Vector2(0, 44)
	b_test.pressed.connect(_playtest)
	btn_row.add_child(b_test)
	var b_verify := Button.new()
	b_verify.text = "Verificar"
	b_verify.pressed.connect(_verify)
	btn_row.add_child(b_verify)
	b_play_sol = Widgets.button("Ver solución")
	b_play_sol.visible = false
	b_play_sol.pressed.connect(func():
		var l := build_level()
		host.show_game(l, {"from_editor": true, "autoplay": _solution}))
	btn_row.add_child(b_play_sol)
	var b_save := Button.new()
	b_save.text = "Guardar"
	b_save.pressed.connect(_save)
	btn_row.add_child(b_save)
	side.add_child(btn_row)

	var b_export := Widgets.button("Exportar código")
	b_export.pressed.connect(_export)
	side.add_child(b_export)
	var b_pub := Widgets.button("Publicar en Comunidad")
	b_pub.tooltip_text = "Estilo Mario Maker: debes superar tu propio nivel en «Probar» antes de publicarlo"
	b_pub.pressed.connect(_publish)
	side.add_child(b_pub)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "Código del nivel (SKM1...)"
	code_edit.editable = false
	side.add_child(code_edit)

	var b_back := Widgets.button("← Menú")
	b_back.pressed.connect(_back_or_warn)
	side.add_child(b_back)

	# init: either load a level or a bordered empty room
	if p_level:
		_load_level(p_level)
	else:
		_new_room()
	_refresh_rules_ui()
	# foco inicial: primera herramienta de la paleta (la acción
	# dominante del editor es pintar con el tile elegido)
	Widgets.focus_first(self)


func _new_room() -> void:
	cells.clear()
	over.clear()
	for y in grid_h:
		for x in grid_w:
			if x == 0 or y == 0 or x == grid_w - 1 or y == grid_h - 1:
				cells[Vector2i(x, y)] = "#"


func _load_level(l: LevelData) -> void:
	editing = l
	title_edit.text = l.title
	author_edit.text = l.author
	hidden_check.button_pressed = l.hidden_rules
	grid_h = l.board.size()
	grid_w = 0
	for line in l.board:
		grid_w = maxi(grid_w, line.length())
	w_spin.value = grid_w
	h_spin.value = grid_h
	cells.clear()
	over = l.over.duplicate(true)
	for y in grid_h:
		var line: String = l.board[y]
		for x in mini(line.length(), grid_w):
			var ch := line[x]
			match ch:
				" ", "-", "_":
					pass
				_:
					cells[Vector2i(x, y)] = ch  # keeps *, +, % intact
	rule_entries.clear()
	for r in l.rules:
		rules_panel.add_rule(r.get("id", ""), r.get("params", {}))
	_invalidate_solution()


func _cell_ok(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < grid_w and p.y < grid_h


# ---------------------------------------------------------- strokes

func begin_stroke() -> void:
	_push_undo()


## Undo entries carry the grid dimensions: resize/rotate change them,
## so restoring only the cells would desync board and cells.
func _push_undo() -> void:
	_undo_stack.append({"cells": cells.duplicate(), "over": over.duplicate(true), "w": grid_w, "h": grid_h})
	if _undo_stack.size() > 100:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_dirty = true
	_invalidate_solution()


## La solución verificada pertenece al tablero anterior: cualquier
## mutación deja el botón «Ver solución» reproduciendo otra cosa.
func _invalidate_solution() -> void:
	_solution = PackedStringArray()
	if b_play_sol != null:
		b_play_sol.visible = false


func _apply_board_state(e: Dictionary) -> void:
	cells = e["cells"]
	over = e.get("over", {})
	grid_w = int(e["w"])
	grid_h = int(e["h"])
	w_spin.value = grid_w
	h_spin.value = grid_h
	grid.custom_minimum_size = Vector2(grid_w, grid_h) * grid.tile
	grid.queue_redraw()
	_refresh_dead()
	_invalidate_solution()


func _editor_undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.append({"cells": cells.duplicate(), "over": over.duplicate(true), "w": grid_w, "h": grid_h})
	_apply_board_state(_undo_stack.pop_back())


func _editor_redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append({"cells": cells.duplicate(), "over": over.duplicate(true), "w": grid_w, "h": grid_h})
	_apply_board_state(_redo_stack.pop_back())


func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and e.ctrl_pressed):
		return
	if e.keycode == KEY_Z:
		if e.shift_pressed:
			_editor_redo()
		else:
			_editor_undo()
	elif e.keycode == KEY_Y:
		_editor_redo()


## Stamp the active tool at p, honoring mirror symmetry.
func _stamp(p: Vector2i, erase: bool) -> void:
	var pts: Array = [p]
	if mirror_x:
		pts.append(Vector2i(grid_w - 1 - p.x, p.y))
	if mirror_y:
		pts.append(Vector2i(p.x, grid_h - 1 - p.y))
	if mirror_x and mirror_y:
		pts.append(Vector2i(grid_w - 1 - p.x, grid_h - 1 - p.y))
	for q in pts:
		if not _cell_ok(q):
			continue
		if erase or tool == " ":
			# primero cae el overlay de ocupante, luego el compuesto
			# pierde solo el ocupante (la meta queda)
			if over.erase(q):
				continue
			var rest := _strip_top(cells.get(q, ""))
			if rest == "":
				cells.erase(q)
			else:
				cells[q] = rest
		else:
			if tool == "@":
				for k in cells.keys():
					if cells[k] == "@" or cells[k] == "+":
						cells.erase(k)
			var res := _compose_tile(tool, cells.get(q, " "))
			if res == "":
				# terreno pisable no componible → caja como overlay
				over[q] = TileSpec.box_spec(tool)
			else:
				# el nuevo char posee la celda entera (terreno u
				# ocupante): sucede a cualquier overlay viejo
				cells[q] = res
				over.erase(q)


## Compuestos viven en TileSpec (fuente única): componer al sellar,
## descomponer al borrar.
func _compose_tile(t: String, cur: String) -> String:
	return TileSpec.compose(t, cur)


func _strip_top(cur: String) -> String:
	return TileSpec.strip_top(cur)


func paint_cell(p: Vector2i, erase: bool) -> void:
	if not _cell_ok(p):
		return
	if shape == "fill" and not erase:
		_flood(p)
	else:
		_stamp(p, erase)
	grid.queue_redraw()


func _flood(p: Vector2i) -> void:
	var target: String = cells.get(p, " ")
	if target == tool:
		return
	# collect the region first, then _stamp each cell — raw writes
	# skipped the "@" dedup and ignored mirror symmetry
	var region := {}
	var stack: Array = [p]
	while not stack.is_empty():
		var q: Vector2i = stack.pop_back()
		if not _cell_ok(q) or region.has(q) or cells.get(q, " ") != target:
			continue
		region[q] = true
		for d in SokobanSolver.DIRS4:
			stack.append(q + d)
	for q in region:
		_stamp(q, false)


func _shape_cells(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	if shape == "line":
		var d := b - a
		var steps := maxi(absi(d.x), absi(d.y))
		for i in maxi(steps, 1) + 1:
			out.append(a + Vector2i(
				roundi(float(d.x) * i / maxi(steps, 1)),
				roundi(float(d.y) * i / maxi(steps, 1))))
	else:  # rect (filled)
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				out.append(Vector2i(x, y))
	return out


func commit_shape(end: Vector2i) -> void:
	_push_undo()
	for c in _shape_cells(drag_anchor, end):
		_stamp(c, false)
	grid.queue_redraw()
	_refresh_dead()


func _eyedrop(p: Vector2i) -> void:
	# si hay overlay de ocupante encima, la herramienta es su caja
	if over.has(p):
		var os: Dictionary = over[p]
		var oc: int = int(os.get("c", 0))
		tool = "bcd"[oc - 1] if oc > 0 \
			else "&" if os.get("m", false) \
			else "q" if os.get("r", false) \
			else "n" if os.get("h", false) else "$"
		if _tool_buttons.has(tool):
			_tool_buttons[tool].button_pressed = true
		Widgets.status(status, "Herramienta: %s" % tool)
		return
	var ch: String = cells.get(p, " ")
	ch = {"+": "@", "*": "$", "%": "&"}.get(ch, ch)
	tool = ch
	# keep the palette's pressed state in sync with the active tool
	if _tool_buttons.has(ch):
		_tool_buttons[ch].button_pressed = true
	Widgets.status(status, "Herramienta: %s" % ch)


# ---------------------------------------------------------- transforms

func _flip_h() -> void:
	_push_undo()
	# direccional tiles must turn too (conveyors, one-ways)
	var nc := {}
	for p in cells.keys():
		nc[Vector2i(grid_w - 1 - p.x, p.y)] = TileSpec.flip_h(cells[p])
	cells = nc
	var no := {}
	for p in over.keys():
		no[Vector2i(grid_w - 1 - p.x, p.y)] = over[p]
	over = no
	grid.queue_redraw()
	_refresh_dead()


func _flip_v() -> void:
	_push_undo()
	var nc := {}
	for p in cells.keys():
		nc[Vector2i(p.x, grid_h - 1 - p.y)] = TileSpec.flip_v(cells[p])
	cells = nc
	var no := {}
	for p in over.keys():
		no[Vector2i(p.x, grid_h - 1 - p.y)] = over[p]
	over = no
	grid.queue_redraw()
	_refresh_dead()


func _zoom_in() -> void:
	grid.tile = minf(grid.tile + 8.0, 64.0)
	grid.custom_minimum_size = Vector2(grid_w, grid_h) * grid.tile
	grid.queue_redraw()


func _zoom_out() -> void:
	grid.tile = maxf(grid.tile - 8.0, 16.0)
	grid.custom_minimum_size = Vector2(grid_w, grid_h) * grid.tile
	grid.queue_redraw()


func _rot90() -> void:
	_push_undo()
	var nc := {}
	for p in cells.keys():
		nc[Vector2i(grid_h - 1 - p.y, p.x)] = TileSpec.rot90(cells[p])
	cells = nc
	var no := {}
	for p in over.keys():
		no[Vector2i(grid_h - 1 - p.y, p.x)] = over[p]
	over = no
	var tmp := grid_w
	grid_w = grid_h
	grid_h = tmp
	w_spin.value = grid_w
	h_spin.value = grid_h
	grid.custom_minimum_size = Vector2(grid_w, grid_h) * grid.tile
	grid.queue_redraw()
	_refresh_dead()


# ---------------------------------------------------------- clipboard

func _copy_board() -> void:
	var lines := PackedStringArray()
	for y in grid_h:
		var row := ""
		for x in grid_w:
			row += str(cells.get(Vector2i(x, y), " "))
		lines.append(row)
	DisplayServer.clipboard_set("\n".join(lines))
	Widgets.status(status, "✓ Tablero copiado al portapapeles.")


func _paste_board() -> void:
	var txt := DisplayServer.clipboard_get()
	if txt.strip_edges() == "":
		Widgets.status(status, "⚠ El portapapeles no contiene un tablero.")
		return
	var lines := txt.split("\n", false)
	_push_undo()
	cells.clear()
	var had_over := not over.is_empty()
	over.clear()  # el texto XSB no puede expresar overlays — pega suelo
	grid_h = clampi(lines.size(), 1, 100)
	grid_w = 1
	for l in lines:
		grid_w = maxi(grid_w, l.length())
	grid_w = clampi(grid_w, 1, 100)
	for y in grid_h:
		for x in mini(lines[y].length(), grid_w):
			var ch := lines[y][x]
			if ch != " " and ch != "-" and ch != "_":
				cells[Vector2i(x, y)] = ch
	w_spin.value = mini(grid_w, int(w_spin.max_value))
	h_spin.value = mini(grid_h, int(h_spin.max_value))
	grid.custom_minimum_size = Vector2(grid_w, grid_h) * grid.tile
	grid.queue_redraw()
	_refresh_dead()
	Widgets.status(status, ("✓ Tablero pegado (%dx%d)." % [grid_w, grid_h])
		+ (" ⚠ Los overlays de caja no viajan en texto plano — se han descartado."
			if had_over else ""))


# ------------------------------------------------------ dead overlay

func _refresh_dead() -> void:
	_dead.clear()
	if not show_dead:
		return
	var s := GameState.from_level_data(build_level())
	if s != null and SokobanSolver.is_classic_state(s):
		_dead = SokobanSolver.dead_cells(s)


func _pick_tool(t: String) -> void:
	tool = t


func _resize_grid() -> void:
	_push_undo()
	grid_w = int(w_spin.value)
	grid_h = int(h_spin.value)
	for k in cells.keys():
		if not _cell_ok(k):
			cells.erase(k)
	for k in over.keys():
		if not _cell_ok(k):
			over.erase(k)
	grid.custom_minimum_size = Vector2(grid_w, grid_h) * grid.tile
	grid.queue_redraw()
	_refresh_dead()


# ---------------------------------------------------------------- rules

func _add_rule(rule_id: String, params: Dictionary = {}) -> void:
	rules_panel.add_rule(rule_id, params)


func _refresh_rules_ui() -> void:
	rules_panel.refresh()


func build_level() -> LevelData:
	var lines := PackedStringArray()
	for y in grid_h:
		var row := ""
		for x in grid_w:
			row += str(cells.get(Vector2i(x, y), " "))
		lines.append(row)
	var rules := rules_panel.to_rules()
	var t := title_edit.text.strip_edges()
	var l := LevelData.create(t if t != "" else "Sin título", lines, rules, author_edit.text.strip_edges())
	l.hidden_rules = hidden_check.button_pressed
	l.over = over.duplicate(true)
	# Keep solver metadata (par/difficulty) only if the playable content
	# is unchanged — a stale par would lie about the level.
	if editing != null and editing.content_code() == l.content_code():
		l.par = editing.par
		l.difficulty = editing.difficulty
	return l


# ---------------------------------------------------------------- actions

func _verify() -> void:
	var l := build_level()
	var problems := l.validate()
	if not problems.is_empty():
		Widgets.status(status, "⚠ " + "; ".join(problems))
		return
	Widgets.status(status, "Buscando solución…")
	var expect := l.content_code()  # si el tablero cambia en medio del
	# "límite de estados" no es veredicto → escala el presupuesto antes
	# de declararse incapaz
	SokobanSolver.solve_async(l, func(res: Dictionary):  # solve, el resultado es obsoleto
		if build_level().content_code() != expect:
			return
		if res.get("ok", false):
			l.difficulty = SokobanSolver.rate_difficulty(res, l)
			l.par = res["moves"].size()
			_solution = res["moves"]
			b_play_sol.visible = true
			Widgets.status(status, "✓ Soluble en %d movimientos. Dificultad:%s"
				% [res["moves"].size(), Widgets.stars(l.difficulty)])
		else:
			var reason: String = res.get("reason", "")
			# "límite de estados" no es un veredicto: el nivel puede ser
			# soluble y el solver simplemente se quedó sin presupuesto
			if reason.contains("límite"):
				Widgets.status(status,
					"✗ El solucionador alcanzó el límite de búsqueda — puede que sea soluble aunque no lo haya probado.")
			else:
				Widgets.status(status, "✗ El nivel es irresoluble (%s)." % reason),
		SokobanSolver.MAX_STATES, true)  # escalate: reintenta ×4 y ×15


func _playtest() -> void:
	var l := build_level()
	var problems := l.validate()
	if not problems.is_empty():
		Widgets.status(status, "⚠ " + "; ".join(problems))
		return
	host.show_game(l, {"from_editor": true, "playtest": l.to_code()})


## Mario Maker rule: you can only publish a level you've beaten in
## playtest (Storage.is_playtested records the clear).
func _publish() -> void:
	var l := build_level()
	var problems := l.validate()
	if not problems.is_empty():
		Widgets.status(status, "⚠ " + "; ".join(problems))
		return
	if not Storage.is_playtested(l):
		Widgets.status(status, "⚠ Para publicar debes superar tu propio nivel: pulsa «Probar» y complétalo.")
		return
	var res := CommunityService.publish(l, author_edit.text.strip_edges())
	if res.get("ok"):
		Widgets.status(status, "✓ Publicado en la Comunidad.")
	else:
		Widgets.status(status, "✗ " + str(res.get("err", "")))


func _save() -> void:
	var l := build_level()
	var problems := l.validate()
	if not problems.is_empty():
		Widgets.status(status, "⚠ " + "; ".join(problems))
		return
	Storage.save_custom_level(l)
	_dirty = false
	Widgets.status(status, "✓ Guardado en Mis niveles.")


## Salir sin guardar: doble-confirmación (mismo patrón que
## «Restaurar por defecto» en Controles y «✕» en Comunidad) —
## antes el botón destruía el trabajo sin avisar.
func _back_or_warn() -> void:
	if not _dirty:
		host.show_menu()
		return
	_dirty = false          # el segundo clic sale de verdad
	Widgets.status(status, "⚠ Tienes cambios sin guardar — pulsa «← Menú» de nuevo para salir.")


func _export() -> void:
	var l := build_level()
	var code := l.to_code()
	code_edit.text = code
	DisplayServer.clipboard_set(code)
	var problems := l.validate()
	if problems.is_empty():
		Widgets.status(status, "✓ Código copiado al portapapeles (%d caracteres)." % code.length())
	else:
		# se puede exportar un nivel roto (work in progress), pero el
		# código tiene que advertir que no está listo para compartir
		Widgets.status(status, "⚠ Exportado, pero el nivel tiene problemas: " + "; ".join(problems))
