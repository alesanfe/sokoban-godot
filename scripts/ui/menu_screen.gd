class_name MenuScreen
extends Control
## Main menu.


func _init(host: Control) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := Widgets.center_vbox(self)
	v.add_child(Widgets.label("SOKOBAN MUTANTE", 44, Color(0.95, 0.8, 0.2)))
	v.add_child(Widgets.label("Cada nivel, una regla absurda.", 16, Color(0.7, 0.7, 0.75)))
	v.add_child(Widgets.hsep())

	var saved = Storage.get_in_progress()
	if saved != null:
		var b_cont := Widgets.button("▶ Continuar: %s" % saved["level"].title)
		b_cont.pressed.connect(func():
			host.show_game(saved["level"], {"resume": true, "saved_state": saved["state"]}))
		v.add_child(b_cont)

	var b_campaign := Widgets.button("Jugar campaña")
	b_campaign.pressed.connect(host.show_level_select)
	v.add_child(b_campaign)

	var b_map := Widgets.button("Mapa del mundo")
	b_map.pressed.connect(host.show_map)
	v.add_child(b_map)

	var b_daily := Widgets.button("Desafío diario")
	b_daily.pressed.connect(func(): _generate_async(host, b_daily,
		func(): return LevelGenerator.daily(), "daily"))
	v.add_child(b_daily)

	var b_random := Widgets.button("Nivel aleatorio")
	b_random.pressed.connect(func(): _generate_async(host, b_random,
		func(): return LevelGenerator.generate(
			randi(), 10, 8, 3, ""),
		"generated"))
	v.add_child(b_random)

	var b_gen := Widgets.button("Desafío personalizado…")
	b_gen.pressed.connect(host.show_generator)
	v.add_child(b_gen)

	var b_editor := Widgets.button("Editor de niveles")
	b_editor.pressed.connect(host.show_editor)
	v.add_child(b_editor)

	var b_import := Widgets.button("Importar código")
	b_import.pressed.connect(host.show_import)
	v.add_child(b_import)

	var b_comm := Widgets.button("Comunidad")
	b_comm.pressed.connect(host.show_community)
	v.add_child(b_comm)

	var b_stats := Widgets.button("Estadísticas")
	b_stats.pressed.connect(host.show_stats)
	v.add_child(b_stats)

	var b_controls := Widgets.button("Controles…")
	b_controls.pressed.connect(host.show_controls)
	v.add_child(b_controls)

	var b_options := Widgets.button("Opciones…")
	b_options.pressed.connect(host.show_options)
	v.add_child(b_options)

	var b_quit := Widgets.button("Salir")
	b_quit.pressed.connect(func(): get_tree().quit())
	v.add_child(b_quit)

	# build id visible: versión del project.godot — los bugreports y
	# el QA de release se apoyan en ella ("¿en qué build pasó?")
	var ver := Widgets.label(
		"v" + str(ProjectSettings.get_setting(
			"application/config/version", "?")),
		12, Color(0.45, 0.45, 0.5))
	v.add_child(ver)

	# a 720p el menú rebosaba (~750px de contenido) y "Salir"/versión
	# quedaban fuera del viewport — comprime para que quepa sin scroll
	v.add_theme_constant_override("separation", 8)
	for c in v.get_children():
		if c is Button:
			c.custom_minimum_size.y = 38


## Generation runs the solver up to 40× per candidate — far too heavy
## for the main thread. Worker thread + deferred callback, like
## SokobanSolver.solve_async.
static func _generate_async(host: Control, btn: Button, gen: Callable, ctx_key: String) -> void:
	if btn.disabled:
		return
	btn.disabled = true
	btn.text = "Generando…"
	# weakrefs: si el menú se cierra durante la generación el callback
	# no debe tocar nodos liberados ni saltar a una partida
	var wbtn: WeakRef = weakref(btn)
	var whost: WeakRef = weakref(host)
	WorkerThreadPool.add_task(func():
		var lvl: LevelData = gen.call()
		(func():
			var b = wbtn.get_ref()
			var h = whost.get_ref()
			if b == null or h == null:
				return
			b.disabled = false
			b.text = "Desafío diario" if ctx_key == "daily" else "Nivel aleatorio"
			if lvl:
				h.show_game(lvl, {ctx_key: true})
			elif h.has_method("toast"):
				h.toast("No se pudo generar — inténtalo de nuevo")
		).call_deferred(), true)
