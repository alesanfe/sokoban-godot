class_name UiTheme
extends RefCounted
## Programmatic UI theme (our ThemeGen equivalent): semantic colors,
## shared styleboxes, light/dark/high-contrast/colorblind variants and
## a visible focus ring for keyboard/gamepad navigation.

const ORDER := ["dark", "light", "contrast", "cb"]
const NAMES := ["Oscuro", "Claro", "Alto contraste", "Daltonismo"]

const VARIANTS := {
	"dark": {
		"bg": Color(0.07, 0.08, 0.10), "panel": Color(0.12, 0.14, 0.17),
		"panel_hi": Color(0.15, 0.18, 0.22), "edge": Color(0.25, 0.30, 0.38),
		"accent": Color(0.95, 0.8, 0.2), "accent_hi": Color(1.0, 0.9, 0.45),
		"text": Color(0.92, 0.93, 0.96), "dim": Color(0.6, 0.63, 0.7),
		"ok": Color(0.35, 0.85, 0.5), "info": Color(0.35, 0.85, 0.95),
		"warn": Color(0.95, 0.75, 0.3),
	},
	"light": {
		"bg": Color(0.90, 0.89, 0.85), "panel": Color(0.98, 0.97, 0.94),
		"panel_hi": Color(0.88, 0.87, 0.82), "edge": Color(0.65, 0.63, 0.58),
		"accent": Color(0.55, 0.38, 0.05), "accent_hi": Color(0.75, 0.55, 0.15),
		"text": Color(0.12, 0.12, 0.15), "dim": Color(0.38, 0.38, 0.42),
		"ok": Color(0.12, 0.55, 0.22), "info": Color(0.05, 0.45, 0.65),
		"warn": Color(0.7, 0.45, 0.0),
	},
	"contrast": {
		"bg": Color(0, 0, 0), "panel": Color(0.05, 0.05, 0.05),
		"panel_hi": Color(0.12, 0.12, 0.12), "edge": Color(0.95, 0.95, 0.95),
		"accent": Color(1.0, 0.85, 0.3), "accent_hi": Color(1.0, 0.95, 0.55),
		"text": Color(1, 1, 1), "dim": Color(0.85, 0.85, 0.85),
		"ok": Color(0.45, 1.0, 0.55), "info": Color(0.5, 0.95, 1.0),
		"warn": Color(1.0, 0.9, 0.3),
	},
	# dark variant tuned for deuteranopia/protanopia (Okabe–Ito accents)
	"cb": {
		"bg": Color(0.07, 0.08, 0.10), "panel": Color(0.12, 0.14, 0.17),
		"panel_hi": Color(0.15, 0.18, 0.22), "edge": Color(0.3, 0.4, 0.55),
		"accent": Color(0.34, 0.65, 0.95), "accent_hi": Color(0.55, 0.8, 1.0),
		"text": Color(0.92, 0.93, 0.96), "dim": Color(0.6, 0.63, 0.7),
		"ok": Color(0.25, 0.8, 0.6), "info": Color(0.55, 0.8, 1.0),
		"warn": Color(0.95, 0.7, 0.25),
	},
}


static func current_mode() -> String:
	var m := str(Storage.get_setting("ui_theme"))
	return m if ORDER.has(m) else ORDER[0]


static func apply(root: Control) -> Theme:
	var mode := current_mode()
	root.theme = make(mode)
	return root.theme


static func bg_color() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["bg"]


## Tokens semánticos para texto coloreado en código (hints, éxito,
## info): las pantallas NO deben hardcodear un gris/verde pensado para
## el tema oscuro — en Claro quedaba por debajo de contraste AA y en
## Alto contraste era invisible.
static func dim() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["dim"]


static func accent() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["accent"]


static func ok() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["ok"]


static func info() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["info"]


static func warn() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["warn"]


static func text() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["text"]


static func panel() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["panel"]


static func edge() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["edge"]


static func accent_hi() -> Color:
	return VARIANTS.get(current_mode(), VARIANTS.dark)["accent_hi"]


## Texto sobre fondo acento: blanco si el acento es oscuro (tema Claro),
## casi-negro si es claro (Oscuro/Contraste/Daltonismo) — siempre AA.
static func on_accent() -> Color:
	return on(accent())


## Texto legible sobre cualquier fondo: luminancia relativa W3C —
## oscuro sobre claro, claro sobre oscuro.
static func on(bg: Color) -> Color:
	var lum := 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
	return Color(0.07, 0.07, 0.08) if lum > 0.45 else Color(0.98, 0.98, 1.0)


static func make(mode: String) -> Theme:
	var v: Dictionary = VARIANTS.get(mode, VARIANTS.dark)
	var t := Theme.new()
	for cls in ["Label", "Button", "LineEdit", "TextEdit", "OptionButton",
			"CheckBox", "CheckButton", "SpinBox", "PopupMenu"]:
		t.set_color("font_color", cls, v.text)
		t.set_color("font_hover_color", "Button", v.accent_hi)
		t.set_color("font_pressed_color", "Button", v.accent)
		t.set_color("font_disabled_color", "Button", v.dim)
		t.set_color("caret_color", "LineEdit", v.accent)
		t.set_color("caret_color", "TextEdit", v.accent)
		t.set_color("font_placeholder_color", "LineEdit", v.dim)
		t.set_color("font_placeholder_color", "TextEdit", v.dim)
		t.set_color("selection_color", "LineEdit", Color(v.accent, 0.35))
		t.set_color("selection_color", "TextEdit", Color(v.accent, 0.35))
		t.set_color("font_selected_color", "OptionButton", v.text)
		t.set_color("font_hover_color", "PopupMenu", v.accent_hi)
		t.set_color("font_disabled_color", "PopupMenu", v.dim)
		t.set_color("font_separator_color", "PopupMenu", v.edge)
	t.set_stylebox("panel", "PanelContainer", _panel(v))
	t.set_stylebox("panel", "PopupPanel", _panel(v))
	t.set_stylebox("panel", "PopupMenu", _panel(v))
	t.set_stylebox("hover", "PopupMenu", _box(v.panel_hi, Color(0, 0, 0, 0), 4, 0))
	t.set_stylebox("normal", "Button", _box(v.panel, v.edge, 6, 1))
	t.set_stylebox("hover", "Button", _box(v.panel_hi, v.accent, 6, 1))
	t.set_stylebox("pressed", "Button", _box(v.panel.darkened(0.2), v.accent, 6, 1))
	t.set_stylebox("focus", "Button", _focus(v.accent))
	t.set_stylebox("disabled", "Button", _box(v.panel.darkened(0.15), v.edge, 6, 1))
	for cls in ["OptionButton", "LineEdit", "TextEdit", "SpinBox"]:
		var base: Color = v.panel.darkened(0.3) if mode != "light" else Color.WHITE
		t.set_stylebox("normal", cls, _box(base, v.edge, 5, 1))
		t.set_stylebox("hover", cls, _box(v.panel_hi, v.edge, 5, 1))
		t.set_stylebox("pressed", cls, _box(v.panel_hi, v.edge, 5, 1))
		t.set_stylebox("focus", cls, _box(base, v.accent, 5, 1))
	var sb := _box(v.panel.lightened(0.15), v.edge, 3, 0)
	for sbn in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(sbn, "VScrollBar", sb)
	t.set_stylebox("background", "VScrollBar", _empty())
	t.set_stylebox("background", "HScrollBar", _empty())
	t.set_stylebox("slider", "HSlider", _box(v.panel_hi, v.edge, 2, 0))
	t.set_stylebox("grabber_area", "HSlider", _box(v.accent, Color(0, 0, 0, 0), 3, 0))
	return t


static func _focus(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = col
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s


static func _box(bg: Color, edge: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


static func _panel(v: Dictionary) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = v.panel
	s.border_color = v.edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
