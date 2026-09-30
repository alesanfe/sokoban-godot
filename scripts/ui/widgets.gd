class_name Widgets
extends RefCounted
## Small UI construction helpers so screens stay readable.


static func label(text: String, size: int = 18, color: Color = Color.WHITE) -> Label:
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
static func juice(b: Button) -> void:
	b.pivot_offset = b.custom_minimum_size / 2.0
	b.button_down.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2(0.96, 0.96), 0.07))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))


static func center_vbox(parent: Control) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	return v


static func hsep() -> HSeparator:
	return HSeparator.new()


## Lightweight toast (ProperUI-Toast equivalent): bottom-center label
## that fades out. Survives screen swaps when parented to the host root.
static func toast(root: Control, text: String, dur := 1.8) -> void:
	var l := label(text, 15, Color(1, 1, 1))
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


static func stars(n: int) -> String:
	if n <= 0:
		return ""
	var s := ""
	for i in n:
		s += "★"
	return " " + s
