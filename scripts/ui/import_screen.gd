class_name ImportScreen
extends Control
## Paste a share code, preview it, play or save it.


func _init(host: Control) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := Widgets.center_vbox(self)
	v.add_child(Widgets.label("Importar nivel", 32, UiTheme.accent()))
	v.add_child(Widgets.label("Pega un código SKM1.…/SKM2.… o un"
		+ " tablero XSB (también RLE: 4#|# @$.#)", 14,
		UiTheme.dim()))

	# TextEdit (not LineEdit) so multi-line XSB boards paste correctly.
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(520, 120)
	edit.placeholder_text = "SKM1.… / SKM2.… o tablero XSB (varias líneas)"
	edit.scroll_fit_content_height = true
	v.add_child(edit)
	# foco en el campo de código (Jugar nace deshabilitado)
	edit.grab_focus.call_deferred()

	# instrucción antes de la entrada: explica por qué Jugar/Guardar
	# nacen deshabilitados (los tooltips no se muestran en disabled)
	var status := Widgets.label(
		"Pega un código o tablero y pulsa «Comprobar» para habilitar Jugar y Guardar.",
		14, UiTheme.dim())
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 520
	v.add_child(status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var b_check := Widgets.button("Comprobar")
	var b_play := Widgets.primary("Jugar")
	var b_save := Widgets.button("Guardar")
	var b_back := Widgets.button("← Menú")
	b_play.disabled = true
	b_save.disabled = true
	row.add_child(b_check)
	row.add_child(b_play)
	row.add_child(b_save)
	row.add_child(b_back)
	v.add_child(row)

	var found: Array = []  # holds decoded LevelData(s)

	# multi-level packs (SKM2 / multi-section XSB): pick which to play
	var pick := OptionButton.new()
	pick.custom_minimum_size.x = 520
	pick.visible = false
	v.add_child(pick)

	b_check.pressed.connect(func():
		found.clear()
		b_play.disabled = true
		b_save.disabled = true
		pick.clear()
		pick.visible = false
		var decoded = LevelData.decode(edit.text)
		var levels: Array = []
		if decoded != null:
			levels = decoded if decoded is Array else [decoded]
		else:
			# not a share code → try raw XSB / XSB-RLE board text
			levels = LevelData.from_xsb_text(edit.text)
		# XSB packs come in titled "Importado" — number them so the
		# picker doesn't show N identical entries
		if levels.size() > 1:
			for li in levels.size():
				levels[li].title = "%s %d" % [levels[li].title, li + 1]
		if levels.is_empty():
			status.text = "Código o tablero inválido."
			return
		var report := PackedStringArray()
		var all_ok := true
		for l in levels:
			var problems: PackedStringArray = l.validate()
			var names := PackedStringArray()
			for r in l.rules:
				names.append(str(RuleRegistry.describe(r.get("id", "")).get("title", "")))
			var tag := "✓" if problems.is_empty() else "✗"
			report.append("%s «%s» — %s%s" % [
				tag, l.title,
				", ".join(names) if not names.is_empty() else "clásico",
				("  (" + "; ".join(problems) + ")") if not problems.is_empty() else "",
			])
			if not problems.is_empty():
				all_ok = false
		status.text = ("Pack de %d niveles:\n" % levels.size() if levels.size() > 1 else "") + "\n".join(report)
		for l in levels:
			if l.validate().is_empty():
				found.append(l)
		if not found.is_empty():
			b_play.disabled = false
			b_save.disabled = false
			if found.size() > 1:
				for l in found:
					pick.add_item(l.title)
				pick.visible = true
	)
	b_play.pressed.connect(func():
		if found.is_empty():
			return
		var i := pick.selected if pick.visible else 0
		host.show_game(found[clampi(i, 0, found.size() - 1)], {"imported": true})
	)
	b_save.pressed.connect(func():
		for l in found:
			Storage.save_custom_level(l)
		status.text = "Guardado en Mis niveles (%d nivel(es))." % found.size()
	)
	b_back.pressed.connect(host.show_menu)
