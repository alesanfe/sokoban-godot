class_name Widgets
extends RefCounted
## Small UI construction helpers so screens stay readable.


static func label(text: String, size: int = 18, color: Color = Color.TRANSPARENT) -> Label:
	# el default era Color.WHITE literal: en el tema Claro toda
	# etiqueta sin color explícito quedaba blanca sobre beige —
	# TRANSPARENT es un sentinel que resuelve al text() del tema
	if color.a == 0.0:
		color = UiTheme.VARIANTS[UiTheme.current_mode()]["text"]
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 44)
	b.add_theme_font_size_override("font_size", 18)
	if not bool(Storage.get_setting("reduce_motion")):
		juice(b)
	return b


## Juicee-lite: subtle squash on press. Cheap, GPU-side, opt-out via
## reduce_motion.
## Acción primaria: fondo acento — la rúbrica UX pide una acción
## principal identificable por pantalla; todos los botones iguales
## no la tienen.
static func primary(text: String) -> Button:
	var b := button(text)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.accent()
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	b.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = UiTheme.accent_hi()
	b.add_theme_stylebox_override("hover", sb_h)
	var fg := UiTheme.on_accent()
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	return b


static func juice(b: Button) -> void:
	b.pivot_offset = b.custom_minimum_size / 2.0
	b.button_down.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2(0.96, 0.96), 0.07))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))


static func center_vbox(parent: Control) -> VBoxContainer:
	# Scroll bajo el Center: el contenido alto (menú a escala 130%,
	# stats largas) cortaba los extremos — el CenterContainer no
	# scrollea, solo centra y recorta
	var s := ScrollContainer.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(s)
	var c := CenterContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	return v


static func hsep() -> HSeparator:
	return HSeparator.new()


## Search-match highlighting (rúbrica 5.4): RichTextLabel con la
## subcadena buscada en negrita+accent sobre el color del tema.
## Devuelve Control para que el llamador pueda usarlo siempre — con
## q vacío se comporta como un label normal.
static func marked(text: String, size: int, q: String,
		col := Color(0, 0, 0, 0)) -> Control:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# sin expand en un contenedor colapsa a ~0px de ancho y el texto
	# se envuelve carácter a carácter (visto en la captura de comunidad)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_font_size_override("bold_font_size", size)
	if col.a == 0.0:
		rt.add_theme_color_override("default_color",
			UiTheme.VARIANTS[UiTheme.current_mode()]["text"])
	else:
		rt.add_theme_color_override("default_color", col)
	var i := -1 if q == "" else text.to_lower().find(q.to_lower())
	if i < 0:
		rt.text = _bbc(text)
	else:
		var hi := UiTheme.accent()
		rt.text = _bbc(text.substr(0, i)) \
			+ "[b][color=#" + hi.to_html(false) + "]" \
			+ _bbc(text.substr(i, q.length())) + "[/color][/b]" \
			+ _bbc(text.substr(i + q.length()))
	return rt


## "[" literal rompería el parser BBCode — escapa antes de insertar.
static func _bbc(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")


## Status-channel setter: writes the label AND speaks the text when
## the screen-reader option is on — the HUD/editor status lines carry
## critical feedback (deadlocks, hints, confirm prompts) that would
## otherwise stay silent for non-sighted users.
static func status(lbl: Label, text: String) -> void:
	lbl.text = text
	if bool(Storage.get_setting("screen_reader")) \
			and DisplayServer.has_feature(
				DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_speak(text, "")


## Lightweight toast (ProperUI-Toast equivalent): bottom-center label
## that fades out. Survives screen swaps when parented to the host root.
static func toast(root: Control, text: String, dur := 1.8) -> void:
	# si el lector está activo los toasts (éxito/error/estado) también
	# se dictan — sin esto el canal principal de feedback era mudo
	if bool(Storage.get_setting("screen_reader")) \
			and DisplayServer.has_feature(
				DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_speak(text, "")
	var l := label(text, 15, Color(1, 1, 1))
	l.name = "Toast"  # localizable: tests y el driver de capturas lo purgan
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.position = Vector2(-160, -56)
	l.custom_minimum_size = Vector2(320, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate = Color(1, 1, 1, 0)
	root.add_child(l)
	var tw := root.create_tween()
	var slow := bool(Storage.get_setting("reduce_motion"))
	tw.tween_property(l, "modulate:a", 1.0, 0.01 if slow else 0.18)
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.finished.connect(l.queue_free)


## Foco inicial para teclado/lector: primer control enfocable en
## orden de árbol (el primer elemento visible de la pantalla).
## Deferred — los screens se construyen en _init, fuera del árbol.
static func focus_first(root: Control) -> void:
	(func():
		var f := _first_focusable(root)
		if f != null:
			f.grab_focus()).call_deferred()


static func _first_focusable(c: Control) -> Control:
	if not c.visible:
		return null
	if (c is BaseButton or c is LineEdit or c is TextEdit) \
			and not (c is BaseButton and c.disabled):
		return c
	for ch in c.get_children():
		var f := _first_focusable(ch)
		if f != null:
			return f
	return null


static func stars(n: int) -> String:
	if n <= 0:
		return ""
	var s := ""
	for i in n:
		s += "★"
	return " " + s
