class_name OptionsScreen
extends Control
## Settings hub: theme, board skin, audio, HUD toggles and gameplay
## knobs — everything persisted in settings.json via Storage.

const SKIN_NAMES := ["Sprites", "Plano", "Retro"]
const AP_SPEEDS := [0.5, 1.0, 2.0, 4.0]
const REPEAT_RATES := [0.18, 0.11, 0.06]
const REPEAT_NAMES := ["Lenta", "Normal", "Rápida"]
const ASSIST_NAMES := ["OFF", "Aviso", "Marcas", "Bloquear"]

var host: Control


func _init(p_host: Control) -> void:
	host = p_host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 560
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	v.add_child(Widgets.label("Opciones", 30, Color(0.95, 0.8, 0.2)))

	# ------------------------------------------------------------ Vídeo
	v.add_child(_section("Vídeo"))
	v.add_child(_cycle("Tema de la interfaz",
		UiTheme.NAMES[UiTheme.ORDER.find(UiTheme.current_mode())],
		func(b: Button):
			var idx := (UiTheme.ORDER.find(UiTheme.current_mode()) + 1) \
				% UiTheme.ORDER.size()
			Storage.set_setting("ui_theme", UiTheme.ORDER[idx])
			host.apply_theme()
			b.text = "Tema de la interfaz: " + UiTheme.NAMES[idx]))
	v.add_child(_cycle("Tablero", SKIN_NAMES[
		clampi(int(Storage.get_setting("board_skin")), 0, SKIN_NAMES.size() - 1)],
		func(b: Button):
			var n := (int(Storage.get_setting("board_skin")) + 1) \
				% SKIN_NAMES.size()
			Storage.set_setting("board_skin", n)
			BoardView.reload_skin()
			b.text = "Tablero: " + SKIN_NAMES[n]))
	v.add_child(Widgets.label(
		"Sprites: Kenney · Plano: look procedural · Retro: sprites con tinte",
		11, Color(0.6, 0.6, 0.65)))

	# ------------------------------------------------------------ Audio
	v.add_child(_section("Audio"))
	v.add_child(_toggle("music", "Música",
		func(on: bool, b: Button):
			Storage.set_setting("music", on)
			if host.music:
				host.music.enabled = on
			b.text = "Música: " + ("ON" if on else "OFF")))
	v.add_child(_slider("Volumen música",
		int(Storage.get_setting("music_vol")),
		func(val: int):
			Storage.set_setting("music_vol", val)
			if host.music:
				# 0..100 → -24..0 dB sobre el nivel base de -16 dB
				host.music.volume_db = -16.0 + (val - 70) * 0.24))
	v.add_child(_toggle("sfx", "Efectos",
		func(on: bool, b: Button):
			Storage.set_setting("sfx", on)
			if host.sfx:
				host.sfx.enabled = on
			b.text = "Efectos: " + ("ON" if on else "OFF")))

	# -------------------------------------------------------------- HUD
	v.add_child(_section("HUD"))
	for opt in [["show_moves", "Mostrar movimientos"],
			["show_timer", "Mostrar tiempo"],
			["show_par", "Mostrar par y mejor marca"]]:
		v.add_child(_check(str(opt[1]),
			bool(Storage.get_setting(opt[0])),
			func(on: bool): Storage.set_setting(opt[0], on)))

	# ------------------------------------------------------- Jugabilidad
	v.add_child(_section("Jugabilidad"))
	v.add_child(_cycle("Asistencia bloqueos", ASSIST_NAMES[
		clampi(int(Storage.get_setting("deadlock_assist")), 0, 3)],
		func(b: Button):
			var n := (int(Storage.get_setting("deadlock_assist")) + 1) % 4
			Storage.set_setting("deadlock_assist", n)
			b.text = "Asistencia bloqueos: " + ASSIST_NAMES[n]))
	v.add_child(_toggle("confirm_restart", "Confirmar reinicio",
		func(on: bool, b: Button):
			Storage.set_setting("confirm_restart", on)
			b.text = "Confirmar reinicio: " + ("ON" if on else "OFF")))
	v.add_child(_toggle("reduce_motion", "Movimiento reducido",
		func(on: bool, b: Button):
			Storage.set_setting("reduce_motion", on)
			b.text = "Movimiento reducido: " + ("ON" if on else "OFF")))

	var ap_idx := _nearest_idx(AP_SPEEDS,
		float(Storage.get_setting("autoplay_speed")))
	v.add_child(_cycle("Velocidad autoplay",
		str(AP_SPEEDS[ap_idx]) + "×",
		func(b: Button):
			var n := (_nearest_idx(AP_SPEEDS,
				float(Storage.get_setting("autoplay_speed"))) + 1) \
				% AP_SPEEDS.size()
			Storage.set_setting("autoplay_speed", AP_SPEEDS[n])
			b.text = "Velocidad autoplay: " + str(AP_SPEEDS[n]) + "×"))

	var rr_idx := _nearest_idx(REPEAT_RATES,
		float(Storage.get_setting("repeat_rate")))
	v.add_child(_cycle("Repetición de tecla", REPEAT_NAMES[rr_idx],
		func(b: Button):
			var n := (_nearest_idx(REPEAT_RATES,
				float(Storage.get_setting("repeat_rate"))) + 1) \
				% REPEAT_RATES.size()
			Storage.set_setting("repeat_rate", REPEAT_RATES[n])
			b.text = "Repetición de tecla: " + REPEAT_NAMES[n]))

	v.add_child(Widgets.hsep())
	v.add_child(Widgets.label(
		"Los controles se reasignan en «Controles…» del menú.",
		12, Color(0.6, 0.6, 0.65)))
	var b_back := Widgets.button("← Menú")
	b_back.pressed.connect(host.show_menu)
	v.add_child(b_back)


func _section(title: String) -> Control:
	var l := Widgets.label(title, 16, Color(0.85, 0.7, 0.3))
	return l


func _cycle(label_text: String, current: String, on_press: Callable) -> Control:
	var b := Widgets.button("%s: %s" % [label_text, current])
	b.pressed.connect(func(): on_press.call(b))
	return b


func _toggle(key: String, label_text: String, on_press: Callable) -> Control:
	var b := Widgets.button("%s: %s" % [label_text,
		"ON" if bool(Storage.get_setting(key)) else "OFF"])
	b.pressed.connect(func():
		on_press.call(not bool(Storage.get_setting(key)), b))
	return b


## Stored value not in the list → clamp to the nearest entry (same
## behavior for every cycling option).
static func _nearest_idx(list: Array, val: float) -> int:
	var best_i := 0
	var best_d := INF
	for i in list.size():
		var d := absf(float(list[i]) - val)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _check(label_text: String, on: bool, on_toggle: Callable) -> Control:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = on
	cb.toggled.connect(on_toggle)
	return cb


func _slider(label_text: String, val: int, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_child(Widgets.label(label_text, 14))
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = val
	sl.custom_minimum_size.x = 200
	sl.value_changed.connect(func(v2: float): on_change.call(int(v2)))
	row.add_child(sl)
	return row
