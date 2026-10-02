class_name GeneratorScreen
extends Control
## Custom challenge generator: pick size, box count, rule and seed —
## a "my way" random level instead of the one-click menu shortcut.

var host: Control
var w_spin: SpinBox
var h_spin: SpinBox
var b_spin: SpinBox
var seed_edit: LineEdit
var rule_pick: OptionButton
var status: Label


func _init(p_host: Control) -> void:
	host = p_host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := Widgets.center_vbox(self)
	v.add_child(Widgets.label("Generador", 30, Color(0.95, 0.8, 0.2)))
	v.add_child(Widgets.label(
		"Tu desafío a medida. Semilla vacía = aleatoria.",
		13, Color(0.6, 0.6, 0.65)))
	v.add_child(Widgets.hsep())

	w_spin = _spin("Ancho", 6, 16, 10, v)
	h_spin = _spin("Alto", 5, 14, 8, v)
	b_spin = _spin("Cajas", 1, 8, 3, v)

	var row := HBoxContainer.new()
	row.add_child(Widgets.label("Regla", 14))
	rule_pick = OptionButton.new()
	rule_pick.add_item("Clásico (sin regla)")
	# solo reglas con efecto en un tablero generado (tiles clásicos)
	for rid in RuleRegistry.all_ids():
		if not LevelGenerator.INERT_ON_GENERATED.has(rid):
			rule_pick.add_item(str(RuleRegistry.describe(rid).get("title", rid)))
	row.add_child(rule_pick)
	v.add_child(row)

	var row2 := HBoxContainer.new()
	row2.add_child(Widgets.label("Semilla", 14))
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "aleatoria"
	seed_edit.custom_minimum_size.x = 140
	row2.add_child(seed_edit)
	v.add_child(row2)

	v.add_child(Widgets.hsep())
	_b_go = Widgets.primary("Generar y jugar")
	_b_go.grab_focus.call_deferred()
	_b_go.pressed.connect(_go)
	v.add_child(_b_go)
	status = Widgets.label("", 13, Color(0.9, 0.6, 0.5))
	v.add_child(status)
	_b_back = Widgets.button("← Menú")
	_b_back.pressed.connect(host.show_menu)
	v.add_child(_b_back)


func _spin(label_text: String, lo: float, hi: float, val: float,
		parent: Control) -> SpinBox:
	var row := HBoxContainer.new()
	var l := Widgets.label(label_text, 14)
	l.custom_minimum_size.x = 80
	row.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = 1
	sb.value = val
	row.add_child(sb)
	parent.add_child(row)
	return sb


var _b_go: Button
var _b_back: Button
var _rule_ids := PackedStringArray()


func _gen_rule_ids() -> PackedStringArray:
	if _rule_ids.is_empty():
		for rid in RuleRegistry.all_ids():
			if not LevelGenerator.INERT_ON_GENERATED.has(rid):
				_rule_ids.append(rid)
	return _rule_ids


func _go() -> void:
	var seed_txt := seed_edit.text.strip_edges()
	var seed: int
	if seed_txt == "":
		seed = randi()
	elif seed_txt.is_valid_int():
		seed = int(seed_txt)
	else:
		status.text = "⚠ La semilla debe ser un número entero."
		return
	var rid := ""
	if rule_pick.selected > 0:
		rid = _gen_rule_ids()[rule_pick.selected - 1]
	var w := int(w_spin.value)
	var h := int(h_spin.value)
	var nb := int(b_spin.value)
	# generation = up to 40 solver passes → off the main thread.
	# La navegación se bloquea y el callback va por weakref: salir a
	# mitad de generación no debe tocar nodos liberados ni saltar a
	# una partida desde el menú.
	_b_go.disabled = true
	_b_back.disabled = true
	status.text = "Generando…"
	var wr: WeakRef = weakref(self)
	WorkerThreadPool.add_task(func():
		var lvl := LevelGenerator.generate(seed, w, h, nb, rid)
		(func():
			var scr = wr.get_ref()
			if scr == null:
				return  # la pantalla se cerró durante la generación
			scr._b_go.disabled = false
			scr._b_back.disabled = false
			if lvl == null:
				scr.status.text = "No se pudo generar — prueba con más espacio o menos cajas."
				return
			lvl.title = "Generado · %dx%d · %s" % [
				w, h, rid if rid != "" else "clásico"]
			scr.host.show_game(lvl, {"generated": true})
		).call_deferred(), true)
