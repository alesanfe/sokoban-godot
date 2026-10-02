extends SceneTree
## Genera las capturas de docs/assets/ con las pantallas reales.
## Hay que correrlo CON ventana (sin --headless): el render dummy no
## produce píxeles. godot --path . -s res://tools/screenshots.gd
## (la ventana aparece unos segundos y se cierra sola)

const OUT := "res://docs/assets/"

var _frame := 0
var _shots: Array = []        # [Callable monta la vista, nombre]
var _i := 0
var _pending := ""            # vista montada, pendiente de capturar
var _wait := 8                # frames a esperar antes de capturar
var _recentered := false


func _initialize() -> void:
	# user:// aislado: no tocar el progreso real del jugador.
	# Se borra para que el seeding sea idempotente entre corridas
	# (bump_total acumula).
	Storage.BASE_DIR = "user://shots/"
	_wipe(Storage.BASE_DIR)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT))
	_seed_progress()
	var main: Control = load("res://scripts/main.gd").new()
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
	]


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
	# por defecto 8 frames por paso: _ready, layout, resized y tweens
	# pintan todo; el shot de victoria espera a que el autoplay acabe
	if _frame < _wait:
		return false
	_frame = 0
	_wait = 8
	if _pending != "":
		# fuerza un re-centrado por si resized disparó con state==null
		if not _recentered and _pending in ["gameplay", "mutant"] \
				and root.get_child_count() > 0:
			var scr: Variant = root.get_child(0).get("current")
			if scr != null and scr.has_method("_center_board"):
				scr._center_board()
				print("dbg tile=%s pos=%s holder=%s px=%s" % [
					scr.board.tile, scr.board.position,
					scr.board_holder.size, scr.board.board_pixel_size()])
			_recentered = true
			return false            # un frame más y se captura
		_recentered = false
		var img := root.get_texture().get_image()
		img.save_png(OUT + _pending + ".png")
		print("shot: ", _pending)
		if _pending == "editor":
			root.size.y = 720              # restaurar para el resto
		_pending = ""
		return _i >= _shots.size()          # último → salir
	if _i < _shots.size():
		_shots[_i][0].call()
		_pending = _shots[_i][1]
		_i += 1
	return false


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
