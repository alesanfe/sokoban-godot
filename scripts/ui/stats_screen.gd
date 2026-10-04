class_name StatsScreen
extends Control
## Progress statistics: per-pack completion, stars, best-move totals,
## total play time and the daily-challenge streak.


func _init(host: Control) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := Widgets.center_vbox(self)
	v.add_child(Widgets.label("Estadísticas", 30, UiTheme.accent()))
	v.add_child(Widgets.hsep())

	# colores de marca por pack — los mismos que el mapa del mundo y
	# los encabezados del selector (stats usaba warn para Mis niveles
	# mientras mapa/selector lo identificaban con accent)
	var packs := [
		["Campaña Mutante", Campaign.levels(), UiTheme.accent()],
		["Clásicos Microban", LevelPack.load_microban(), UiTheme.info()],
		["Mis niveles", Storage.custom_levels(), UiTheme.accent()],
	]
	var tot_moves := 0
	var tot_time := 0.0
	for pack in packs:
		var levels: Array = pack[1]
		var done := 0
		var stars := 0
		var moves := 0
		for l in levels:
			var bm := Storage.best_moves(l)
			if bm > 0:
				done += 1
				moves += bm
				tot_moves += bm
				tot_time += Storage.best_time(l)
				stars += _stars(l, bm)
		v.add_child(Widgets.label("%s:  %d/%d  ·  %d★  ·  %d mov." % [
			pack[0], done, levels.size(), stars, moves], 16, pack[2]))

	v.add_child(Widgets.hsep())
	v.add_child(Widgets.label("Tiempo total de tus mejores soluciones: %02d:%02d" % [
		int(tot_time) / 3600, (int(tot_time) % 3600) / 60], 15, UiTheme.info()))
	var streak := Storage.daily_streak()
	v.add_child(Widgets.label("Desafíos diarios: %d completados · racha de %d día%s" % [
		Storage.daily_total(), streak, "" if streak == 1 else "s"],
		15, UiTheme.accent()))
	var t := Storage.totals()
	v.add_child(Widgets.label("Toda tu actividad: %d victorias · %d movimientos · %d empujes" % [
		int(t.get("wins", 0)), int(t.get("moves", 0)), int(t.get("pushes", 0))],
		13, UiTheme.dim()))
	v.add_child(Widgets.label("%d deshacer · %d reinicios · %d pistas" % [
		int(t.get("undos", 0)), int(t.get("restarts", 0)), int(t.get("hints", 0))],
		13, UiTheme.dim()))
	v.add_child(Widgets.hsep())
	var b_back := Widgets.button("← Menú")
	b_back.pressed.connect(host.show_menu)
	v.add_child(b_back)
	Widgets.focus_first(self)


func _stars(l: LevelData, best: int) -> int:
	if l.par <= 0:
		return 1
	if best <= l.par:
		return 3
	if best <= int(l.par * 1.5):
		return 2
	return 1
