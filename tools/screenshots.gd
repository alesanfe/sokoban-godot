extends SceneTree
## Genera las capturas de docs/assets/screenshots/ con las pantallas reales.
## Hay que correrlo CON ventana (sin --headless): el render dummy no
## produce píxeles. godot --path . -s res://tools/screenshots.gd
## (la ventana aparece unos segundos y se cierra sola)

const OUT := "res://docs/assets/screenshots/"
const SIZE_OUT := "res://docs/assets/_sizes/"   # barrido de ventana

var _frame := 0
var _shots: Array = []        # [Callable monta la vista, nombre]
var _size_jobs: Array = []    # [Vector2i, Callable, nombre]
var _theme_jobs: Array = []   # [modo, Callable, nombre]
var _main: Control
var _i := 0
var _si := 0
var _ti := 0
var _pending := ""            # vista montada, pendiente de capturar
var _wait := 8                # frames a esperar antes de capturar
var _recentered := false
var _retries := 0             # recolocaciones pendientes de layout
var _cur_size := Vector2i(1280, 720)   # tamaño pedido en el barrido
var _subset: Array = []       # filtro por nombre: -- menu state_toast
                             # (vacío = barrido completo)
var _total_frames := 0        # calentamiento: sin él, un subset que
                             # empieza tarde capturaba la ventana aún
                             # en blanco (visto: PNGs de 4 KB vacíos)
const WARMUP_FRAMES := 40


func _initialize() -> void:
	_subset = OS.get_cmdline_user_args()
	# user:// aislado: no tocar el progreso real del jugador.
	# Se borra para que el seeding sea idempotente entre corridas
	# (bump_total acumula).
	Storage.BASE_DIR = "user://shots/"
	_wipe(Storage.BASE_DIR)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT))
	_seed_progress()
	var main: Control = load("res://scripts/main.gd").new()
	_main = main
	# main.tscn le da FULL_RECT; instanciado por script nace con size 0
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child.call_deferred(main)
	_shots = [
		[func(): main.show_menu(), "menu"],
		[func(): main.show_game(_demo_level()), "gameplay"],
		[func(): main.show_game(Campaign.levels()[30]), "mutant"],
		[func(): main.show_level_select(), "select"],
		[func(): _editor_shot(main), "editor"],
		[func(): _import_shot(main), "import"],
		[func(): main.show_community(), "community"],
		[func(): main.show_map(), "map"],
		[func(): main.show_stats(), "stats"],
		[func(): main.show_options(), "options"],
		[func(): main.show_controls(), "controls"],
		[func(): _generator_shot(main), "generator"],
		[func(): _deadlock_shot(main), "deadlock"],
		[func(): _hint_shot(main), "hint"],
		[func(): _trail_shot(main), "trail"],
		[func(): _win_shot(main), "win"],
		# estados, no solo vistas: vacío/error/foco/toast/denso — el
		# camino feliz de las capturas anteriores nunca los mostraba
		[func(): _state_empty(main), "state_empty"],
		[func(): _state_import_err(main), "state_import_err"],
		[func(): _state_focus(main), "state_focus"],
		[func(): _state_toast(main), "state_toast"],
		[func(): _state_editor_big(main), "state_editor_big"],
		# estados de servicio: solver en marcha, repetición, veredicto
		# de «Verificar» y la puerta de publicación sin playtest
		[func(): _state_solve(main), "state_solve"],
		[func(): _state_replay(main), "state_replay"],
		[func(): _state_verify(main), "state_verify"],
		[func(): _state_publish(main), "state_publish_gate"],
		# confirmaciones destructivas armadas + stress de contenido:
		# textos que no caben y aspecto retrato
		[func(): _state_confirm(main), "state_confirm"],
		[func(): _state_unsaved(main), "state_unsaved"],
		[func(): _state_longtext(main), "state_longtext"],
		[func(): _state_portrait(main), "size_menu_700x900"],
		# orden de tabulación: ¿el anillo aterriza en un control
		# visible y sensato tras N Tab, o se pierde en algo oculto?
		[func(): _state_tab(func(): main.show_level_select(), 5),
			"state_tab_select"],
		[func(): _state_tab(
			func(): main.show_game(_demo_level()), 3),
			"state_tab_game"],
		[func(): _state_tab(
			func(): main.show_editor(_demo_level()), 4),
			"state_tab_editor"],
	]
	# barrido de ventana: las pantallas clave a varios tamaños para
	# auditar el responsive — salen a _sizes/, no al README
	var sizes := [Vector2i(800, 600), Vector2i(1024, 600),
		Vector2i(1600, 900)]
	for sz in sizes:
		_size_jobs.append([sz, func(): main.show_menu(),
			"menu"])
		_size_jobs.append([sz, func(): main.show_game(_demo_level()),
			"gameplay"])
		_size_jobs.append([sz, func(): main.show_level_select(),
			"select"])
		_size_jobs.append([sz, func(): main.show_options(),
			"options"])
	# barrido de temas: los literales que escaparon a tokens solo se
	# ven contra fondo claro / contraste / daltonismo — el dark es el
	# tema para el que fue diseñada toda la UI, ahí todo "luce bien"
	for mode in ["light", "contrast", "cb"]:
		for v in [["menu", func(): main.show_menu()],
				["gameplay", func(): main.show_game(_demo_level())],
				["select", func(): main.show_level_select()],
				["community", func(): main.show_community()],
				["editor", func(): main.show_editor(_demo_level())]]:
			_theme_jobs.append([mode, v[1], v[0]])
	# escala 130%: los layouts que no reajustan revientan aquí
	for v in [["menu", func(): main.show_menu()],
			["options", func(): main.show_options()]]:
		_theme_jobs.append(["scale130", v[1], v[0]])


## Nivel de muestra: varios tiles especiales que saltan a la vista
## (cintas + portales + cajas/metas de color).
func _demo_level() -> LevelData:
	return LevelData.create("La guarida mutante", PackedStringArray([
		"###########",
		"#@  b  c  #",
		"#  ##  ## #",
		"# > >>^v  #",
		"#  B  C   #",
		"###o#####O#",
		"###########",
	]), [{"id": "conveyor", "params": {}},
		{"id": "portal", "params": {}}])


func _process(_dt: float) -> bool:
	_frame += 1
	_total_frames += 1
	# los saltos del subset se resuelven sin esperar — solo la vista
	# montada espera sus frames de layout
	while _advance_queue():
		pass
	if _pending == "":
		return _queue_done()
	# la primera captura espera al warmup del renderer; una ventana
	# recién creada devuelve textura en blanco los primeros frames
	if _total_frames < WARMUP_FRAMES:
		return false
	# por defecto 8 frames por paso: _ready, layout, resized y tweens
	# pintan todo; el shot de victoria espera a que el autoplay acabe
	if _frame < _wait:
		return false
	_frame = 0
	# 14 frames ≈ 230ms > fade-in de pantalla (0.15s): con 8 la
	# captura caía a veces a medio fundido y era no-determinista
	_wait = 14
	if _pending != "":
		# fuerza un re-centrado por si resized disparó con state==null
		if not _recentered and (_pending in ["gameplay", "mutant"]
				or _pending.begins_with("size_gameplay")) \
				and root.get_child_count() > 0:
			var scr: Variant = root.get_child(0).get("current")
			if scr != null and scr.has_method("_center_board"):
				# el holder puede seguir con el tamaño anterior al
				# resize — centrar ya dejaría el tablero recortado en
				# la captura (visto: holder 924px a ventana 1024)
				if scr.board_holder.size.x > float(_cur_size.x) - 240.0 \
						and _retries < 40:
					_retries += 1
					_frame = _wait - 2      # reintenta en 2 frames
					return false
				scr._center_board()
				print("dbg tile=%s pos=%s holder=%s px=%s" % [
					scr.board.tile, scr.board.position,
					scr.board_holder.size, scr.board.board_pixel_size()])
			_recentered = true
			return false            # un frame más y se captura
		_recentered = false
		_retries = 0
		var img := root.get_texture().get_image()
		var dir := SIZE_OUT if _pending.begins_with("size_") else OUT
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(dir))
		img.save_png(dir + _pending + ".png")
		print("shot: ", _pending)
		if _pending == "editor":
			root.size.y = 720              # restaurar para el resto
		if _pending == "size_menu_700x900":
			root.size = Vector2i(1280, 720)
		_pending = ""
		return false
	return false


## Monta la siguiente captura pendiente en _pending y devuelve true.
## Las entradas fuera del subset se saltan sin coste de frames, así
## el bucle while de _process avanza hasta la siguiente captura real.
func _advance_queue() -> bool:
	if _pending != "":
		return false
	if _i < _shots.size():
		var entry: Array = _shots[_i]
		_i += 1
		if not _subset.is_empty() and not _subset.has(entry[1]):
			return true              # salto gratis — sigue el bucle
		_purge_transient()
		entry[0].call()
		_pending = entry[1]
		return false
	# barrido de resoluciones tras las capturas del README
	if _si < _size_jobs.size():
		var job: Array = _size_jobs[_si]
		var sz_name := "size_%s_%dx%d" % [job[2], job[0].x, job[0].y]
		_si += 1
		if not _subset.is_empty() and not _subset.has(sz_name):
			return true
		_purge_transient()
		root.size = job[0]
		_cur_size = job[0]
		job[1].call()
		_pending = sz_name
		return false
	# tercer barrido: temas y escala — re-montar la vista tras aplicar
	# para que los tokens resueltos al construir se refresquen
	if _ti < _theme_jobs.size():
		var job: Array = _theme_jobs[_ti]
		var mode: String = job[0]
		var th_name := "theme_%s_%s" % [job[2], mode]
		_ti += 1
		if not _subset.is_empty() and not _subset.has(th_name):
			return true
		_purge_transient()
		if mode == "scale130":
			root.content_scale_factor = 1.3
		else:
			root.content_scale_factor = 1.0
			Storage.set_setting("ui_theme", mode)
			_main.apply_theme()
		root.size = Vector2i(1280, 720)
		job[1].call()
		_pending = th_name
		return false
	return false


func _queue_done() -> bool:
	if _i < _shots.size() or _si < _size_jobs.size() \
			or _ti < _theme_jobs.size():
		return false
	# limpiar para la próxima corrida
	root.content_scale_factor = 1.0
	Storage.set_setting("ui_theme", "dark")
	_main.apply_theme()
	return true


## El editor es la pantalla más alta (grid + paleta + toolbar);
## se captura con la ventana algo más alta para que nada quede
## cortado abajo, y se restaura al salir. Se le da un nivel con
## contenido — la cuadrícula vacía no enseña nada.
func _editor_shot(main: Control) -> void:
	root.size.y = 860
	main.show_editor(_demo_level())


## El importador se captura con un código pegado — la TextEdit
## vacía era solo un rectángulo negro.
func _import_shot(main: Control) -> void:
	main.show_import()
	for n in root.find_children("*", "TextEdit", true, false):
		(n as TextEdit).text = "#######\n#@ $ .#\n#######"


## El generador con una regla mutante seleccionada — "Clásico
## (sin regla)" no enseña lo que el juego hace.
func _generator_shot(main: Control) -> void:
	main.show_generator()
	for n in root.find_children("*", "OptionButton", true, false):
		(n as OptionButton).selected = mini(6,
			(n as OptionButton).item_count - 1)


## Marcas de deadlock: nivel clásico con la asistencia (Marca) — las
## casillas de las que ninguna caja puede llegar a meta se pintan.
## Un empuje para que no parezca el frame 0.
func _deadlock_shot(main: Control) -> void:
	# la caja queda empujada contra la pared izquierda: casilla muerta
	# → la ✕ roja sobre la caja y el tinte de las demás son visibles;
	# ~25 frames para que el autoplay ejecute el movimiento
	_wait = 25
	main.show_game(LevelData.create("Cuidado con las esquinas",
		PackedStringArray([
			"########",
			"#      #",
			"#  .   #",
			"# $@   #",
			"#      #",
			"########",
		]), []), {"autoplay": PackedStringArray(["l"])})


## Flecha de pista (H): el solver corre en worker; ~150 frames dan
## margen de sobra para que vuelva y pinte la flecha cyan.
func _hint_shot(main: Control) -> void:
	_wait = 150
	main.show_game(LevelData.create("Hacia la meta",
		PackedStringArray([
			"########",
			"#      #",
			"# @ $. #",
			"#      #",
			"########",
		]), []))
	(func():
		await root.get_tree().process_frame
		var scr: Variant = root.get_child(0).get("current")
		if scr != null and scr.has_method("_hint"):
			scr._hint()).call_deferred()


## Mejor ruta (T): puntos sobre las casillas visitadas por la
## repetición guardada — hay que grabar una solución primero
## para que la ruta exista.
func _trail_shot(main: Control) -> void:
	_wait = 25
	# solución en L (bajar, bajar, 3 empujes a la derecha): el trail
	# dibuja un recodo legible en vez de una fila tapada por la caja
	var lvl := LevelData.create("La ruta óptima", PackedStringArray([
		"#########",
		"#       #",
		"# @     #",
		"#   ##  #",
		"#  $  . #",
		"#       #",
		"#########",
	]), [])
	Storage.record_win(lvl,
		PackedStringArray(["d", "d", "r", "r", "r"]), 12.0)
	main.show_game(lvl, {})
	(func():
		await root.get_tree().process_frame
		var scr: Variant = root.get_child(0).get("current")
		if scr != null and scr.has_method("_toggle_trail"):
			scr._toggle_trail()).call_deferred()


## Panel de victoria: autoplay resuelve un nivel trivial (3 empujes)
## y se espera a que el panel termine de aparecer.
func _win_shot(main: Control) -> void:
	# ~190 frames: autoplay (3×0.16s) + confetti (one_shot, vida 1.4s)
	# disipado — capturar antes tapaba el panel con partículas
	_wait = 190
	main.show_game(LevelData.create("Primer empujón", PackedStringArray([
		"#######",
		"#@ $ .#",
		"#######",
	]), []), {"autoplay": PackedStringArray(["r", "r", "r"])})


## Estado vacío de la búsqueda de comunidad: filtro sin resultados
## — el shot normal solo mostraba filas pobladas.
func _state_empty(main: Control) -> void:
	_wait = 15
	main.show_community()
	(func():
		await root.get_tree().process_frame
		var scr: Variant = root.get_child(0).get("current")
		if scr != null:
			scr._search.text = "xyzqq sin resultados"
			scr._populate()).call_deferred()


## Error de importación: código malformado → el mensaje de error
## debe verse (y leerse) en el label de estado.
func _state_import_err(main: Control) -> void:
	main.show_import()
	(func():
		await root.get_tree().process_frame
		for n in root.find_children("*", "TextEdit", true, false):
			(n as TextEdit).text = "SKM1:basura-no-valida"
		for n in root.find_children("*", "Button", true, false):
			if (n as Button).text == "Comprobar":
				(n as Button).pressed.emit()).call_deferred()


## Anillo de foco: el foco de teclado es invisible en un shot normal
## — forzado sobre un botón intermedio queda en la imagen.
func _state_focus(main: Control) -> void:
	main.show_menu()
	(func():
		await root.get_tree().process_frame
		var found := root.find_children("*", "Button", true, false)
		for n in found:
			if (n as Button).text == "Editor de niveles":
				(n as Button).grab_focus()
				return).call_deferred()


## Toast: flota ~2s y es efímero por diseño — hay que capturarlo en
## el acto para auditar su contraste y posición.
func _state_toast(main: Control) -> void:
	main.show_community()
	(func():
		await root.get_tree().process_frame
		Widgets.toast(main, "✓ Guardado en Mis niveles")).call_deferred()


## Editor con un nivel grande (30×18): la paleta ocupa media
## pantalla — a ver qué pasa cuando el tablero también es ancho.
func _state_editor_big(main: Control) -> void:
	root.size.y = 860
	var rows := PackedStringArray()
	for _i in 9:
		rows.append("#" + " ".repeat(28) + "#")
		rows.append("####" + " ".repeat(25) + "#")
	var lvl := LevelData.create("El hangar", rows, [])
	main.show_editor(lvl)


## Solver en marcha: el estado "Buscando solución…" — el único
## momento en que el juego está ocupado sin respuesta todavía.
## Se fija el estado directamente (no se lanza el solver real):
## el worker es no-determinista y la captura sería flaky — lo que
## se audita aquí es el render del estado, no la búsqueda.
func _state_solve(main: Control) -> void:
	root.size = Vector2i(1280, 720)
	main.show_game(Campaign.levels()[30])
	(func():
		await root.get_tree().process_frame
		var scr: Variant = root.get_child(0).get("current")
		if scr != null and scr.has_method("_solve"):
			scr._solving = true
			Widgets.status(scr.hud_status, "Buscando solución…")
		).call_deferred()


## Repetición en vuelo: una win grabada + _replay_saved() — el
## tablero se captura a mitad de la reproducción, no en reposo.
func _state_replay(main: Control) -> void:
	root.size = Vector2i(1280, 720)
	_wait = 14   # ~1-2 movimientos de la repetición (0.16s cada uno)
	var lvl := LevelData.create("Vuelta atrás", PackedStringArray([
		"#########",
		"#       #",
		"# @ $  .#",
		"#       #",
		"#########",
	]), [])
	Storage.record_win(lvl,
		PackedStringArray(["r", "r", "r", "r"]), 9.0)
	main.show_game(lvl, {})
	(func():
		await root.get_tree().process_frame
		var scr: Variant = root.get_child(0).get("current")
		if scr != null and scr.has_method("_replay_saved"):
			scr._replay_saved()).call_deferred()


## Resultado de «Verificar» en el editor: el solver responde
## "✓ Soluble en N movimientos. Dificultad:…" — el estado que
## convierte un diseño en un nivel publicable.
func _state_verify(main: Control) -> void:
	root.size.y = 860
	_wait = 200  # solver async en worker: margen de sobra
	main.show_editor(LevelData.create("Verificable", PackedStringArray([
		"#######",
		"#@ $ .#",
		"#######",
	]), []))
	(func():
		await root.get_tree().process_frame
		for n in root.find_children("*", "Button", true, false):
			if (n as Button).text == "Verificar":
				(n as Button).pressed.emit()
				return).call_deferred()


## Puerta de publicación estilo Mario Maker: «Publicar» sin haber
## superado el nivel en «Probar» → el aviso con la explicación
## debe leerse en el status del editor.
func _state_publish(main: Control) -> void:
	root.size.y = 860
	# nivel válido (el demo tiene portales sin pareja y abortaría
	# antes en validación — no llegaría a la puerta de playtest)
	main.show_editor(LevelData.create("Publicable", PackedStringArray([
		"#######",
		"#@ $ .#",
		"#######",
	]), []))
	(func():
		await root.get_tree().process_frame
		for n in root.find_children("*", "Button", true, false):
			if (n as Button).text == "Publicar en Comunidad":
				(n as Button).pressed.emit()
				return).call_deferred()


## Confirmación armada: «Restaurar por defecto» cambia su texto a
## "Pulsa de nuevo para confirmar" — el patrón doble-clic tiene
## que leerse claramente (¿parece un estado o un error?).
func _state_confirm(main: Control) -> void:
	root.size = Vector2i(1280, 720)
	main.show_controls()
	(func():
		await root.get_tree().process_frame
		await root.get_tree().process_frame
		for n in root.find_children("*", "Button", true, false):
			if (n as Button).text == "Restaurar por defecto":
				var b := n as Button
				b.pressed.emit()
				# el botón está bajo el fold — el shot tiene que
				# mostrar el estado armado, no la lista de teclas.
				# ensure_control_visible tras un frame: fijar
				# scroll_vertical antes del layout se clampeaba a 0
				await root.get_tree().process_frame
				for s in root.find_children(
						"*", "ScrollContainer", true, false):
					(s as ScrollContainer).ensure_control_visible(b)
				return).call_deferred()


## Aviso de trabajo sin guardar: «← Menú» con _dirty dispara la
## doble-confirmación en vez de salir — el aviso se audita.
func _state_unsaved(main: Control) -> void:
	root.size.y = 860
	main.show_editor(_demo_level())
	(func():
		await root.get_tree().process_frame
		var scr: Variant = root.get_child(0).get("current")
		if scr == null:
			return
		scr._dirty = true   # simula una edición
		for n in root.find_children("*", "Button", true, false):
			if (n as Button).text == "← Menú":
				(n as Button).pressed.emit()
				return).call_deferred()


## Stress de texto: un título de 90 caracteres + autor largo —
## los botones de Godot no recortan por defecto; si el título se
## sale de la fila o tapa al vecino, aquí se ve.
func _state_longtext(main: Control) -> void:
	root.size = Vector2i(1280, 720)
	var lvl := LevelData.create(
		"El laberinto definitivo del guardián que no sabía "
		+ "cuándo dejar de empujar cajas",
		PackedStringArray([
			"#######",
			"#@ $ .#",
			"#######",
		]), [{"id": "conveyor", "params": {}},
			{"id": "portal", "params": {}}])
	lvl.author = "Equipo de diseño de niveles extremadamente verboso"
	Storage.save_custom_level(lvl)
	main.show_level_select()
	(func():
		await root.get_tree().process_frame
		var scr: Variant = root.get_child(0).get("current")
		if scr != null and scr.get("_scroll") != null:
			scr._scroll.scroll_vertical = 99999).call_deferred()


## Aspecto retrato (700×900): todo el barrido era apaisado — los
## layouts centrados pueden comportarse distinto en estrecho/alto.
func _state_portrait(main: Control) -> void:
	# el tamaño se restaura tras la captura en _process (como
	# "editor" con su altura extra) — restaurarlo aquí llegaba
	# antes del shot
	root.size = Vector2i(700, 900)
	main.show_menu()


## Recorrido de foco: monta la vista, envía N Tab reales por el
## pipeline de input (foco GUI completo, no grab_focus directo)
## y captura dónde quedó el anillo.
func _state_tab(mount: Callable, tabs: int) -> void:
	mount.call()
	(func():
		for _i in tabs:
			await root.get_tree().process_frame
			var ev := InputEventKey.new()
			ev.keycode = KEY_TAB
			ev.pressed = true
			Input.parse_input_event(ev)
			var ev2 := InputEventKey.new()
			ev2.keycode = KEY_TAB
			Input.parse_input_event(ev2)).call_deferred()


## Los toasts viven ~2.1s (~10 shots) y cruzan la frontera entre
## capturas — se eliminan antes de montar cada vista para que cada
## shot solo muestre lo que su propia vista produce.
func _purge_transient() -> void:
	for n in _main.find_children("Toast", "", true, false):
		n.free()


static func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_wipe(dir + sub + "/")
	d.remove(dir)


## Progreso de muestra: los shots de select/mapa/stats con todo a
## cero parecen un juego vacío. El user:// aislado hace que esto
## no toque el progreso real del jugador.
func _seed_progress() -> void:
	var camp := Campaign.levels()
	for i in range(0, 26, 2):
		var moves := PackedStringArray()
		for _j in 6 + i % 9:
			moves.append("r")
		Storage.record_win(camp[i], moves, 20.0 + i)
	# contadores de actividad coherentes con las victorias sembradas
	# (sin esto stats mostraba "13/81" pero "0 victorias")
	Storage.bump_total("wins", 13)
	Storage.bump_total("moves", 126)
	Storage.bump_total("pushes", 41)
	Storage.bump_total("undos", 17)
	Storage.bump_total("restarts", 6)
	Storage.bump_total("hints", 3)
	# un nivel custom para que el feed/mapa lo tengan
	Storage.save_custom_level(_demo_level())
