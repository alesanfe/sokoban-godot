class_name WinPanel
extends PanelContainer
## Panel de victoria: resumen + acciones (siguiente/replay/compartir/
## menú). El GameScreen solo conecta señales y pasa el texto del
## resumen (WinStats); el layout, el scroll-clamp y los botones son
## responsabilidad del panel.

signal next_pressed
signal replay_pressed
signal share_pressed
signal menu_pressed

var label: Label
var _scroll: ScrollContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	# sin grow BOTH el preset ancla la esquina superior-izquierda al
	# centro: el panel se desplazaba a la derecha y se salía de la
	# ventana (visible en docs/assets/win.png)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(380, 0)
	visible = false
	# Scroll fallback: on small windows the panel can exceed the
	# viewport — clamp it so the buttons are always reachable.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 10)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(wv)
	label = Widgets.label("¡Nivel completado!", 22, Color(0.4, 0.9, 0.5))
	wv.add_child(label)
	# two rows of paired buttons: compact enough to fit small windows
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 8)
	wv.add_child(brow)
	var b_next := Widgets.primary("Siguiente nivel")
	b_next.grab_focus.call_deferred()   # foco en la acción principal
	b_next.pressed.connect(func(): next_pressed.emit())
	brow.add_child(b_next)
	var b_rep := Widgets.button("Ver mi repetición")
	b_rep.pressed.connect(func(): replay_pressed.emit())
	brow.add_child(b_rep)
	var brow2 := HBoxContainer.new()
	brow2.alignment = BoxContainer.ALIGNMENT_CENTER
	brow2.add_theme_constant_override("separation", 8)
	wv.add_child(brow2)
	var b_share := Widgets.button("Compartir solución")
	b_share.pressed.connect(func():
		share_pressed.emit()
		b_share.text = "✓ Nivel+solución copiados")
	brow2.add_child(b_share)
	var b_menu := Widgets.button("Menú")
	b_menu.pressed.connect(func(): menu_pressed.emit())
	brow2.add_child(b_menu)


func set_summary(text: String) -> void:
	label.text = text


## Muestra el panel clameado a la altura del viewport — sin el clamp,
## un resumen alto (medalla + badges) empuja los botones fuera.
func show_panel(viewport_h: float) -> void:
	visible = true
	# medir antes del primer layout devuelve un min-size pequeño y la
	# fila de botones quedaba cortada a medias
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	_scroll.custom_minimum_size.y = minf(
		_scroll.get_child(0).get_combined_minimum_size().y + 8.0,
		viewport_h - 24.0)
