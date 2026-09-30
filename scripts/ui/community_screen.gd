class_name CommunityScreen
extends Control
## "Modo Comunidad" estilo Mario Maker: explora niveles publicados,
## dales like, juega o descárgalos. Datos vía CommunityService (local
## hoy; la API podría apuntar a un servidor sin cambiar esta pantalla).

const SORT_TABS := [
	["recent", "Recientes"],
	["likes", "Populares"],
	["plays", "Más jugadas"],
	["clears", "Más superadas"],
]

var host: Control
var _sort := "recent"
var _tabs: Array = []
var _list: VBoxContainer
var _search: LineEdit


func _init(p_host: Control) -> void:
	host = p_host
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
	top.add_child(Widgets.label("  Comunidad", 26, Color(0.95, 0.8, 0.2)))
	var hint := Widgets.label("Publica desde el editor: debes superar tu propio nivel primero.", 13, Color(0.6, 0.6, 0.65))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(hint)
	v.add_child(top)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t in SORT_TABS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.pressed.connect(func():
			_sort = t[0]
			for tb in _tabs:
				tb.button_pressed = tb == b
			_populate())
		tabs.add_child(b)
		_tabs.append(b)
	_tabs[0].button_pressed = true
	v.add_child(tabs)

	# búsqueda por título o autor dentro del feed
	var search := HBoxContainer.new()
	search.add_child(Widgets.label("🔍", 14))
	_search = LineEdit.new()
	_search.placeholder_text = "Buscar por título o autor…"
	_search.custom_minimum_size.x = 260
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): _populate())
	search.add_child(_search)
	v.add_child(search)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	CommunityService.seed_officials()
	_populate()


const PAGE := 20  # cada fila construye un thumbnail (GameState+BoardView)


func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	var es := CommunityService.entries(_sort)
	var q := _search.text.strip_edges().to_lower()
	if q != "":
		es = es.filter(func(e):
			return str(e.get("title", "")).to_lower().contains(q) \
				or str(e.get("author", "")).to_lower().contains(q))
	if es.is_empty():
		_list.add_child(Widgets.label(
			"Sin resultados para «%s»." % q if q != ""
				else "Aún no hay niveles publicados.",
			15, Color(0.6, 0.6, 0.65)))
		return
	_append_rows(es.slice(0, PAGE))
	if es.size() > PAGE:
		_more_button(es, PAGE)


func _append_rows(chunk: Array) -> void:
	for e in chunk:
		_list.add_child(_row(e))


func _more_button(es: Array, from: int) -> void:
	var b := Widgets.button("Mostrar más (%d restantes)" % (es.size() - from))
	b.pressed.connect(func():
		b.queue_free()
		var nxt := mini(from + PAGE, es.size())
		_append_rows(es.slice(from, nxt))
		if es.size() > nxt:
			_more_button(es, nxt))
	_list.add_child(b)


func _row(e: Dictionary) -> Control:
	var l: LevelData = e["level"]
	var panel := PanelContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)

	var holder := Control.new()
	var mini := BoardView.new(GameState.from_level_data(l))
	mini.tile = 10.0
	holder.custom_minimum_size = mini.board_pixel_size()
	holder.add_child(mini)
	h.add_child(holder)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(Widgets.label(l.title + Widgets.stars(l.difficulty), 17))
	var d := Time.get_date_string_from_unix_time(e["ts"])
	info.add_child(Widgets.label("por %s · %s" % [e["author"], d], 12, Color(0.6, 0.6, 0.65)))
	info.add_child(Widgets.label("♥ %d   ▶ %d   ✓ %d" % [
		e["likes"], e["plays"], e["clears"]], 13, Color(0.9, 0.6, 0.6)))
	if e["own"]:
		info.add_child(Widgets.label("(tu publicación)", 11, Color(0.95, 0.8, 0.3)))
	h.add_child(info)

	# botones compactos: el mínimo 260×44 de Widgets.button desbordaría la fila
	var b_play := Widgets.button("Jugar")
	b_play.custom_minimum_size = Vector2(96, 44)
	b_play.pressed.connect(func(): host.show_game(l, {"community": e["id"]}))
	h.add_child(b_play)
	var b_like := Widgets.button("♥" if e["liked"] else "♡")
	b_like.custom_minimum_size = Vector2(48, 44)
	b_like.pressed.connect(func():
		CommunityService.like(e["id"])
		_populate())
	h.add_child(b_like)
	var b_dl := Widgets.button("Guardar")
	b_dl.custom_minimum_size = Vector2(110, 44)
	b_dl.tooltip_text = "Copia el nivel a «Mis niveles»"
	b_dl.pressed.connect(func():
		Storage.save_custom_level(l)
		b_dl.text = "✓")
	h.add_child(b_dl)
	# compartir offline: el código SKM1 viaja pegado (chat/mensaje) —
	# sin backend, es el canal real de distribución de la comunidad
	var b_share := Widgets.button("⤴")
	b_share.custom_minimum_size = Vector2(48, 44)
	b_share.tooltip_text = "Copiar el código del nivel (SKM1…)"
	b_share.pressed.connect(func():
		DisplayServer.clipboard_set(l.to_code())
		b_share.text = "✓")
	h.add_child(b_share)
	if e["own"]:
		var b_del := Widgets.button("✕")
		b_del.custom_minimum_size = Vector2(48, 44)
		b_del.tooltip_text = "Retirar la publicación (clic dos veces)"
		var armed := false
		b_del.pressed.connect(func():
			if not armed:
				armed = true
				b_del.text = "¿?"
				get_tree().create_timer(2.0).timeout.connect(func():
					armed = false
					if is_instance_valid(b_del):
						b_del.text = "✕")
				return
			CommunityService.remove(e["id"])
			_populate())
		h.add_child(b_del)
	return panel
