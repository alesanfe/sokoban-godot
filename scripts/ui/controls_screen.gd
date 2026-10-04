class_name ControlsScreen
extends Control
## Key rebinding: click an action, press the new key. Persisted in
## settings.json. Arrows always work as an alternative for movement.

const ACTIONS := [
	["up", "Mover arriba"], ["down", "Mover abajo"],
	["left", "Mover izquierda"], ["right", "Mover derecha"],
	["undo", "Deshacer"], ["redo", "Rehacer"], ["restart", "Reiniciar"],
	["solve", "Solución automática"], ["hint", "Pista"],
	["replay", "Repetición"], ["trail", "Mostrar mejor ruta"],
	["switch", "Cambiar empujador"],
]
const DEFAULTS := {
	"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
	"undo": KEY_Z, "redo": KEY_Y, "restart": KEY_R, "solve": KEY_F1,
	"hint": KEY_H, "replay": KEY_V, "trail": KEY_T, "switch": KEY_SPACE,
}

var host: Control
var _capturing := ""
var _buttons: Dictionary = {}
var _status: Label


func _init(p_host: Control) -> void:
	host = p_host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := Widgets.center_vbox(self)
	# a 720p el conjunto (~770px) cortaba título y botón inferior —
	# separación y filas más compactas para que quepa sin scroll
	v.add_theme_constant_override("separation", 8)
	v.add_child(Widgets.label("Controles", 28, UiTheme.accent()))
	v.add_child(Widgets.label("Clic en una acción y pulsa la nueva"
		+ " tecla. Las flechas siempre funcionan.", 13,
		UiTheme.dim()))
	v.add_child(Widgets.hsep())
	for a in ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lbl := Widgets.label(a[1], 16)
		lbl.custom_minimum_size.x = 200
		row.add_child(lbl)
		var b := Widgets.button(_key_name(a[0]))
		b.custom_minimum_size = Vector2(140, 44)
		b.pressed.connect(func():
			_capturing = a[0]
			# without this Space/Enter would re-trigger the focused
			# button instead of reaching _unhandled_input
			b.release_focus()
			Widgets.status(_status,
				"Pulsa una tecla para «%s» (Esc cancela)" % a[1]))
		row.add_child(b)
		_buttons[a[0]] = b
		v.add_child(row)
	v.add_child(Widgets.hsep())
	_status = Widgets.label("", 14, UiTheme.ok())
	v.add_child(_status)
	var b_reset := Widgets.button("Restaurar por defecto")
	var _armed := false
	b_reset.pressed.connect(func():
		if not _armed:
			_armed = true
			b_reset.text = "Pulsa de nuevo para confirmar"
			Widgets.set_danger(b_reset, true)
			get_tree().create_timer(2.0).timeout.connect(func():
				_armed = false
				if is_instance_valid(b_reset):
					b_reset.text = "Restaurar por defecto"
					Widgets.set_danger(b_reset, false))
			return
		for a in DEFAULTS.keys():
			Storage.set_setting("key_" + a, DEFAULTS[a])
		_refresh())
	v.add_child(b_reset)
	var b_back := Widgets.button("← Menú")
	b_back.pressed.connect(host.show_menu)
	v.add_child(b_back)
	Widgets.focus_first(self)


func _key_name(action: String) -> String:
	var kc := int(Storage.get_setting("key_" + action, DEFAULTS[action]))
	return OS.get_keycode_string(kc)


func _refresh() -> void:
	for a in _buttons.keys():
		_buttons[a].text = _key_name(a)


func _unhandled_input(e: InputEvent) -> void:
	if _capturing == "" or not (e is InputEventKey and e.pressed):
		return
	if e.keycode == KEY_ESCAPE:
		_capturing = ""
		Widgets.status(_status, "Cancelado.")
		return
	Storage.set_setting("key_" + _capturing, e.keycode)
	# same key on two actions → the second one silently dead-binds
	var clash := ""
	for a2 in ACTIONS:
		if a2[0] != _capturing \
				and int(Storage.get_setting("key_" + a2[0], DEFAULTS[a2[0]])) == e.keycode:
			clash = a2[1]
			break
	Widgets.status(_status, "Asignado: %s%s" % [OS.get_keycode_string(e.keycode),
		"  ⚠ también asignada a «%s»" % clash if clash != "" else ""])
	_capturing = ""
	_refresh()
